package com.caremark.gdx.sqml;

import java.sql.SQLException;

/**
 * @author Bryan Castillo
 *
 */
public class CommandSet extends AbstractXMLCommand {

	private final static org.apache.log4j.Logger logger = org.apache.log4j.Logger
			.getLogger(CommandSet.class.getName());
	
	String property;
	String value;
	
	/**
	 * @param script
	 * @throws SqlXmlException
	 * @throws SQLException
	 * @see com.caremark.gdx.sqml.ICommand#execute(com.caremark.gdx.sqml.SqlXmlScript)
	 */
	public void execute(SqlXmlScript script) throws SqlXmlException,
			SQLException
	{
		String _value = script.expandProperties(value);
		logger.debug("execute: set property=[" + property + "] value=[" + _value + "] expr=[" + value + "]");
		script.setProperty(property, _value);
	}

	/**
	 * @return Returns the property.
	 */
	public String getProperty() {
		return property;
	}
	/**
	 * @param property The property to set.
	 */
	public void setProperty(String property) {
		this.property = property;
	}
	/**
	 * @return Returns the value.
	 */
	public String getValue() {
		return value;
	}
	/**
	 * @param value The value to set.
	 */
	public void setValue(String value) {
		this.value = value;
	}
}
