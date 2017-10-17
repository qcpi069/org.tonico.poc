package com.caremark.gdx.sqml;

import java.sql.SQLException;
import java.util.ArrayList;
import java.util.LinkedList;
import java.util.List;

import org.w3c.dom.Element;
import org.xml.sax.SAXException;

import com.caremark.gdx.common.util.XMLUtil;

/**
 * @author Bryan Castillo
 *
 */
public class CopyTargetQueue extends AbstractXMLCopyTarget {

	private final static org.apache.log4j.Logger logger = org.apache.log4j.Logger
			.getLogger(CopyTargetQueue.class.getName());
	
	private LinkedList queue = new LinkedList();
	private int maxQueueSize = 10;
	private int threadCount = 5;
	
	private boolean queueStopped = false;
	private CopyTargetQueueThread[] runnables = null;
	private Thread[] threads = null;
	private Throwable threadError = null;
	
	/**
	 * @param element
	 * @throws Exception
	 * @see com.caremark.gdx.common.IXMLInitializable#initialize(org.w3c.dom.Element)
	 */
	public void initialize(Element element) throws Exception {
		Element[] nodes;
		ICopyTarget subTarget;
		ArrayList subTargetsList;
		ICopyTarget[] subTargets;

		super.initialize(element);
		runnables = new CopyTargetQueueThread[threadCount];
		
		// Create all of the Runnables
		// The XML elements are parsed multiple times to create copies
		// for each Runnable.
		for (int i=0; i<runnables.length; i++) {
			nodes = XMLUtil.getElementsByTagName(element, "target");
			subTargetsList = new ArrayList();
			for (int j=0; j<nodes.length; j++) {
				subTarget = (ICopyTarget) getScript().parse(ICopyTarget.class, nodes[j]);
				subTargetsList.add(subTarget);
			}
			if (subTargetsList.size() < 1) {
				throw new SAXException("There should be at least 1 sub target in the queue copy target.");
			}
			subTargets = (ICopyTarget[]) subTargetsList.toArray(new ICopyTarget[subTargetsList.size()]);
			runnables[i] = new CopyTargetQueueThread(getScript(), this, subTargets);
		}
	}
	
	/**
	 * @throws SqlXmlException
	 * @throws SQLException
	 * @see com.caremark.gdx.sqml.ICopyTarget#start()
	 */
	public void start() throws SqlXmlException, SQLException {
		synchronized (queue) {
			queueStopped = false;
		}
		threads = new Thread[threadCount];
		for (int i=0; i<threadCount; i++) {
			threads[i] = new Thread(runnables[i]);
			threads[i].setName("CopyTargetQueueThread-" + i);
			threads[i].start();
		}
	}
	
	/**
	 * @throws SqlXmlException
	 * @throws SQLException
	 * @see com.caremark.gdx.sqml.ICopyTarget#finish()
	 */
	public void finish() throws SqlXmlException, SQLException {
		Throwable t;
		
		logger.info("finish: waiting for threads to complete......");
		logger.info("finish: items on queue " + getQueueSize());
		
		
		waitForQueueCompletion();
		if (threads != null) {
			for (int i=0; i<threads.length; i++) {
				if (threads[i] != null) {
					try {
						threads[i].join();
						logger.info("finish: joined " + threads[i]);
					}
					catch (InterruptedException ie) {
						logger.error("finish: " + ie.getMessage(), ie);
					}
					threads[i] = null;
				}
			}
		}
		super.finish();
		
		t = getThreadError(true);
		if (t != null) {
			throw new SqlXmlException("Thread error: " + t.getMessage(), t);
		}
	}

	/**
	 * @param rows
	 * @throws SqlXmlException
	 * @throws SQLException
	 * @see com.caremark.gdx.sqml.ICopyTarget#copyRows(java.util.List)
	 */
	public void copyRows(List rows) throws SqlXmlException, SQLException {
		Throwable threadError = null;
		boolean success = false;
		
		if (rows == null) {
			return;
		}
		try {
			logger.debug("copyRows: Adding rows to queue");
			addRow(rows);
			logger.debug("copyRows: size = " + getQueueSize());
			threadError = getThreadError(true);
			if (threadError != null) {
				throw new SqlXmlException("Thread error: " + threadError.getMessage(), threadError);
			}
			success = true;
		}
		finally {
			if (!success) {
				logger.error("copyRows: closing queue on copy error.");
				synchronized (queue) {
					queueStopped = true;
					queue.clear();
					queue.notifyAll();
				}
			}
		}
	}
	
	
	/**
	 * Get the last thread error.
	 * @return
	 */
	public Throwable getThreadError(boolean clearError) {
		synchronized (queue) {
			Throwable t = threadError;
			if (clearError) {
				threadError = null;
			}
			return t;
		}
	}
	
	/**
	 * Threads will call this method when an error occurs in a thread.
	 * @param t
	 */
	public void onThreadError(Throwable t, boolean overwrite) {
		if (t == null) {
			return;
		}
		synchronized (queue) {
			if ((threadError == null) || (overwrite)) {
				threadError = t;
			}
			queueStopped = true;
			queue.notifyAll();
		}
	}
	
	/**
	 * Get the thread queue size.
	 * @return
	 */
	public int getQueueSize() {
		synchronized (queue) {
			return queue.size();
		}
	}
	
	/**
	 * Wait for the queue to drain.
	 * @throws SqlXmlException
	 */
	protected void waitForQueueCompletion() throws SqlXmlException {
		synchronized (queue) {
			while ((queue.size() > 0) && (!queueStopped)) {
				try {
					logger.debug("waitForQueueCompletion: waiting for completion.....");
					queue.wait();
				}
				catch (InterruptedException ie) {
					queueStopped = true;
					queue.notifyAll();
					throw new SqlXmlException(ie);
				}
			}
			queueStopped = true;
			queue.notifyAll();
		}

		logger.debug("waitForQueueCompletion: completed.");
	}
	
	/**
	 * Adds a row to the queue.
	 * 
	 * @param row
	 * @throws SqlXmlException
	 */
	public void addRow(List rows) throws SqlXmlException {
		if (rows == null) {
			throw new IllegalArgumentException("rows is null");
		}
		synchronized (queue) {
			if (queueStopped) {
				throw new SqlXmlException("queue is stopped");
			}
			while (queue.size() >= maxQueueSize) {
				if (queueStopped) {
					throw new SqlXmlException("queue is stopped");
				}
				try {
					queue.wait();
				}
				catch (InterruptedException ie) {
					// if a thread interrupt comes around let everyone
					// know the queue is stopped.
					queueStopped = true;
					queue.notifyAll();
					throw new SqlXmlException(ie);
				}
			}
			queue.addLast(rows);
			queue.notifyAll();
		}
	}
	
	/**
	 * Get a list of rows from the thread queue
	 * @return
	 */
	public List getRows() {
		List rows = null;
		synchronized (queue) {
			while (rows == null) {
				if (queueStopped) {
					return null;
				}
				if (queue.size() > 0) {
					rows = (List) queue.removeFirst();
					queue.notifyAll();
				}
				else {
					try {
						queue.wait();
					}
					catch (InterruptedException ie) {
						return null;
					}
				}
			}
		}
		return rows;
	}


	/**
	 * @return Returns the maxQueueSize.
	 */
	public int getMaxQueueSize() {
		return maxQueueSize;
	}
	/**
	 * @param maxQueueSize The maxQueueSize to set.
	 */
	public void setMaxQueueSize(int maxQueueSize) {
		this.maxQueueSize = maxQueueSize;
	}
	/**
	 * @return Returns the threadCount.
	 */
	public int getThreadCount() {
		return threadCount;
	}
	/**
	 * @param threadCount The threadCount to set.
	 */
	public void setThreadCount(int threadCount) {
		if (threadCount < 1) {
			throw new IllegalArgumentException("Invalid threadCount " + threadCount);
		}
		this.threadCount = threadCount;
	}
}
