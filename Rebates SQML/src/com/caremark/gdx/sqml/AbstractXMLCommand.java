package com.caremark.gdx.sqml;

import java.sql.Connection;
import java.sql.SQLException;
import java.util.Properties;

import org.w3c.dom.Element;

import com.caremark.gdx.common.IDisposable;
import com.caremark.gdx.common.IXMLInitializable;
import com.caremark.gdx.common.util.XMLUtil;

/**
 * @author Bryan Castillo
 *
 */
public abstract class AbstractXMLCommand implements IXMLInitializable, ICommand, IDisposable {

	private Properties properties;
	private String content;
	private SqlXmlScript script;
	private String datasource;
	private Connection connection;

	/**
	 * @throws Exception
	 * @see com.caremark.gdx.common.IDisposable#dispose()
	 */
	public void dispose() throws Exception {
		getScript().closeConnection(connection);
		connection = null;
	}
	
	/**
	 * @param element
	 * @throws Exception
	 * @see com.caremark.gdx.common.IXMLInitializable#initialize(org.w3c.dom.Element)
	 */
	public void initialize(Element element) throws Exception {
		properties = getScript().applyElementProperties(this, element);
		content = XMLUtil.getCharacterData(element);
	}

	/**
	 * @param script
	 * @throws SqlXmlException
	 * @see com.caremark.gdx.sqml.ICommand#onCommandLoad(com.caremark.gdx.sqml.SqlXmlScript)
	 */
	public void onLoad(SqlXmlScript script) throws SqlXmlException {
		this.script = script;
	}

	
	
	/**
	 * Get a connection.
	 * 
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
	 * @param script The script to set.
	 */
	public void setScript(SqlXmlScript script) {
		this.script = script;
	}
	/**
	 * @return Returns the datasource.
	 */
	public String getDatasource() {
		return datasource;
	}
	/**
	 * @param dataSource The datasource to set.
	 */
	public void setDatasource(String datasource) {
		this.datasource = datasource;
	}
}
