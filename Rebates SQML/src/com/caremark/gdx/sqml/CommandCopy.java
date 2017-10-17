// Created: Aug 18, 2005    File: CommandCopy.java
package com.caremark.gdx.sqml;

import java.sql.SQLException;
import java.util.ArrayList;

import org.w3c.dom.Element;
import org.w3c.dom.NodeList;
import org.xml.sax.SAXException;

import com.caremark.gdx.common.util.XMLUtil;

/**
 * @author castillo.bryan@gmail.com
 */
public class CommandCopy extends AbstractXMLCommand {

	private final static org.apache.log4j.Logger logger = org.apache.log4j.Logger
			.getLogger(CommandCopy.class.getName());
	
	private int batch = 100;
	private ICopySource source;
	private ICopyTarget[] targets;

	/**
	 * Calls finish on sources and targets.
	 * @throws Exception
	 */
	protected void finish() throws SqlXmlException, SQLException {
		Exception lastException = null;
		try {
			if (source != null) {
				source.finish();
			}
		}
		catch (Exception e) {
			logger.error("dispose: " + e.getMessage(), e);
			lastException = e;
		}
		if (targets != null) {
			for (int i=0; i<targets.length; i++) {
				try {
					targets[i].finish();
				}
				catch (Exception e) {
					logger.error("dispose: " + e.getMessage(), e);
					lastException = e;
				}
			}
		}
		if (lastException != null) {
			if (lastException instanceof SqlXmlException) {
				throw (SqlXmlException) lastException;
			}
			else if (lastException instanceof SQLException) {
				throw (SQLException) lastException;
			}
			else {
				throw new SqlXmlException(lastException);
			}
		}
	}
	
	/**
	 * @param element
	 * @throws Exception
	 * @see com.caremark.gdx.common.IXMLInitializable#initialize(org.w3c.dom.Element)
	 */
	public void initialize(Element element) throws Exception {
		NodeList nodes;
		Object o = null;
		ArrayList targets = new ArrayList();
		
		super.initialize(element);
		
		// Parse nested elements
		nodes = element.getChildNodes();
		for (int i=0; i<nodes.getLength(); i++) {
			if (nodes.item(i) instanceof Element) {
				o = parseChild(getScript(), (Element) nodes.item(i), null);
				if (o instanceof ICopySource) {
					if (source != null) {
						throw new SAXException("More than 1 source element encountered in a copy command.");
					}
					source = (ICopySource) o;
				}
				else if (o instanceof ICopyTarget) {
					targets.add(o);
				}
			}
		}
		
		// Convert targets into an array
		if (targets.size() < 1) {
			throw new SAXException("There must be at least 1 target in a copy command.");
		}
		this.targets = (ICopyTarget[]) targets.toArray(new ICopyTarget[targets.size()]);
	}

	/**
	 * @param script
	 * @throws SqlXmlException
	 * @see com.caremark.gdx.sqml.ICommand#execute(com.caremark.gdx.sqml.SqlXmlScript)
	 */
	public void execute(SqlXmlScript script)
		throws SqlXmlException, SQLException
	{
		String[] columns;
		int[] columnTypes;
		Object[] row;
		int rowCount = 0;
		int copiedRows = 0;
		ArrayList rows;
		
		// start
		source.start();
		columns = source.getColumnLabels();
		columnTypes = source.getColumnTypes();
		// set column labels
		for (int i=0; i<targets.length; i++) {
			targets[i].setColumnLabels(columns);
			targets[i].setColumnTypes(columnTypes);
		}
		
		try {
			// start the targets
			for (int i=0; i<targets.length; i++) {
				targets[i].start();
			}
			
			// Copy the rows
			rows = new ArrayList(batch);
			rowCount = 0;
			while ((row = source.getRow()) != null) {
				rows.add(row);
				rowCount++;
				if (rowCount >= batch) {
					for (int i=0; i<targets.length; i++) {
						targets[i].copyRows(rows);
					}
					rows = new ArrayList(batch);
					copiedRows += rowCount;
					logger.debug("execute: copied " + copiedRows + " rows.");
					rowCount = 0;
				}
			}
			if (rowCount > 0) {
				for (int i=0; i<targets.length; i++) {
					targets[i].copyRows(rows);
				}
				copiedRows += rowCount;
				logger.debug("execute: copied " + copiedRows + " rows.");
				rowCount = 0;
			}
		}
		finally {
			finish();
		}
	}
	
	/**
	 * Parses an xml element containing either a ICopySource or ICopyTarget.
	 * If expectedType is not null
	 *  
	 * @param script
	 * @param node
	 * @param expectedType
	 * @return
	 * @throws Exception
	 */
	public static ISqlXmlObject parseChild(SqlXmlScript script, Element node,
		String expectedType)
		throws Exception
	{
		String type = null;
		
		if (script == null) {
			throw new SqlXmlException("script is null");
		}
		if (node == null) {
			throw new SqlXmlException("node is null");
		}
		
		if ((expectedType != null) && (expectedType.equals(type))) {
			throw new SAXException("Expected element of type " + expectedType +
				" - " + XMLUtil.toString(node));
		}
		
		type = node.getNodeName();
		if (type.equals("source")) {
			return script.parse(ICopySource.class, node);
		}
		else if (type.equals("target")) {
			return script.parse(ICopyTarget.class, node);
		}
		else {
			throw new SAXException("Unknown copy child element " + type +
				" - " + XMLUtil.toString(node));
		}
	}

	/**
	 * @return Returns the batch.
	 */
	public int getBatch() {
		return batch;
	}
	/**
	 * @param batch The batch to set.
	 */
	public void setBatch(int batch) {
		if (batch < 1) {
			throw new IllegalArgumentException("Invalid value for batch " + batch);
		}
		this.batch = batch;
	}
}
