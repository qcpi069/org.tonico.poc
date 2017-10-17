package com.caremark.gdx.sqml;

import java.sql.Connection;
import java.sql.SQLException;
import java.util.Properties;

import org.w3c.dom.Element;

import com.caremark.gdx.common.IXMLInitializable;
import com.caremark.gdx.common.util.XMLUtil;

/**
 * @author Bryan Castillo
 *
 */
public abstract class AbstractXMLCopySource implements ICopySource, IXMLInitializable {
	
	private SqlXmlScript script;
	private Properties properties;
	private String content;
	private String datasource;
	private String[] columnLabels;
	private int[] columnTypes;
	private Connection connection;
	
	/**
	 * @param element
	 * @throws Exception
	 * @see com.caremark.gdx.common.IXMLInitializable#initialize(org.w3c.dom.Element)
	 */
	public void initialize(Element element) throws Exception {
		getScript().applyElementProperties(this, element);
		content = XMLUtil.getCharacterData(element);
	}
	
	/**
	 * @param script
	 * @throws SqlXmlException
	 * @see com.caremark.gdx.sqml.ICopySource#onLoad(com.caremark.gdx.sqml.CommandCopy)
	 */
	public void onLoad(SqlXmlScript script) throws SqlXmlException {
		this.script = script;
	}
	
	/**
	 * @throws SqlXmlException
	 * @throws SQLException
	 * @see com.caremark.gdx.sqml.ICopySource#finish(com.caremark.gdx.sqml.CommandCopy)
	 */
	public void finish() throws SqlXmlException, SQLException {
		getScript().closeConnection(connection);
		connection = null;
	}
	
	/**
	 * Get a connection
	 * @return
	 */
	public Connection getConnection() throws SqlXmlException, SQLException {
		if (connection == null) {
			connection = getScript().getConnection(getDatasource());
		}
		return connection;
	}
	
	/**
	 * @return Returns the content.
	 */
	public String getContent() {
		return content;
	}
	/**
	 * @param content The content to set.
	 */
	public void setContent(String content) {
		this.content = content;
	}
	/**
	 * @return Returns the script.
	 */
	public SqlXmlScript getScript() {
		return script;
	}
	/**
	 * @return Returns the properties.
	 */
	public Properties getProperties() {
		return properties;
	}
	/**
	 * @return Returns the datasource.
	 */
	public String getDatasource() {
		return datasource;
	}
	/**
	 * @param datasource The datasource to set.
	 */
	public void setDatasource(String datasource) {
		this.datasource = datasource;
	}
	/**
	 * @return Returns the columnLabels.
	 */
	public String[] getColumnLabels() {
		return columnLabels;
	}
	/**
	 * @param columnLabels The columnLabels to set.
	 */
	public void setColumnLabels(String[] columnLabels) {
		this.columnLabels = columnLabels;
	}
	/**
	 * @return Returns the columnTypes.
	 */
	public int[] getColumnTypes() {
		return columnTypes;
	}
	/**
	 * @param columnTypes The columnTypes to set.
	 */
	public void setColumnTypes(int[] columnTypes) {
		this.columnTypes = columnTypes;
	}
}