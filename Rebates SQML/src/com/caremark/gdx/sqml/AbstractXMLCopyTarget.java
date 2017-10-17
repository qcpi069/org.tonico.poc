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
public abstract class AbstractXMLCopyTarget implements ICopyTarget, IXMLInitializable {

	private final static org.apache.log4j.Logger logger = org.apache.log4j.Logger
			.getLogger(AbstractXMLCopyTarget.class.getName());
	
	private SqlXmlScript script;
	private Properties properties;
	private String content;
	private String datasource;
	private String[] columnLabels;
	public int[] columnTypes;
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
	 * @see com.caremark.gdx.sqml.ICopyTarget#onLoad(com.caremark.gdx.sqml.CommandCopy)
	 */
	public void onLoad(SqlXmlScript script) throws SqlXmlException {
		this.script = script;
	}
	
	/**
	 * @throws SqlXmlException
	 * @throws SQLException
	 * @see com.caremark.gdx.sqml.ICopyTarget#finish(com.caremark.gdx.sqml.CommandCopy)
	 */
	public void finish() throws SqlXmlException, SQLException {
		getScript().closeConnection(connection);
		connection = null;
	}
	
	/**
	 * @param columnLabels
	 * @throws SqlXmlException
	 * @throws SQLException
	 * @see com.caremark.gdx.sqml.ICopyTarget#setColumnLabels(com.caremark.gdx.sqml.CommandCopy, java.lang.String[])
	 */
	public void setColumnLabels(String[] columnLabels)
			throws SqlXmlException, SQLException
	{
		this.columnLabels = columnLabels;
	}

	/**
	 * Get a connection
	 * @return
	 */
	public Connection getConnection() throws SqlXmlException, SQLException {
		if (connection == null) {
			logger.debug("getConnection");
			connection = getScript().getConnection(getDatasource());
			logger.debug("getConnection done");
		}
		return connection;
	}
	
	/**
	 * @return Returns the columnLabels.
	 */
	public String[] getColumnLabels() {
		return columnLabels;
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
	 * @return Returns the properties.
	 */
	public Properties getProperties() {
		return properties;
	}
	/**
	 * @param properties The properties to set.
	 */
	public void setProperties(Properties properties) {
		this.properties = properties;
	}
	/**
	 * @return Returns the script.
	 */
	public SqlXmlScript getScript() {
		return script;
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
