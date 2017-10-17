package com.caremark.gdx.sqml;

import java.sql.BatchUpdateException;
import java.sql.SQLException;
import java.util.List;

/**
 * @author Bryan Castillo
 *
 */
public class CopyTargetQueueThread implements Runnable {

	private final static org.apache.log4j.Logger logger = org.apache.log4j.Logger
			.getLogger(CopyTargetQueueThread.class.getName());
	
	private CopyTargetQueue queue;
	private ICopyTarget[] targets;
	private SqlXmlScript script;
	
	public CopyTargetQueueThread(SqlXmlScript script, CopyTargetQueue queue, ICopyTarget[] targets) {
		this.queue = queue;
		this.targets = targets;
		this.script = script;
	}
	
	public void run() {
		List rows = null;
		try {
			
			// Start the targets
			for (int i=0; i<targets.length; i++) {
				targets[i].start();
			}
			
			// copy rows
			while ((rows = queue.getRows()) != null) {
				for (int i=0; i<targets.length; i++) {
					targets[i].copyRows(rows);
				}
			}
		}
		catch (Throwable t) {
			if (t instanceof SQLException) {
				SQLException sqle = (SQLException) t;
				while (sqle != null) {
					logger.error("run: " + sqle.getMessage(), sqle);
					if (sqle.getNextException() == sqle) {
						sqle = null;
					}
					else {
						sqle = sqle.getNextException();
					}
				}
			}
			else {
				logger.error("run: " + t.getMessage(), t);
			}
			queue.onThreadError(t, true);
		}
		finally {
			// finish the targets
			for (int i=0; i<targets.length; i++) {
				try {
					targets[i].finish();
				}
				catch (Throwable t) {
					queue.onThreadError(t, false);
				}
			}
			logger.warn("run: " + Thread.currentThread() + " exiting.");
			script.clearThreadResources(Thread.currentThread());
		}
	}

}
