package com.caremark.gdx.sqml;

import org.apache.commons.beanutils.ConvertUtils;

/**
 * @author Bryan Castillo
 *
 */
public class DirectiveProperty extends AbstractXMLDirective {

	private String name;
	private String value;
	private String type = null;
	
	/**
	 * @param script
	 * @throws SqlXmlException
	 * @see com.caremark.gdx.sqml.IDirective#execute(com.caremark.gdx.sqml.SqlXmlScript)
	 */
	public void execute(SqlXmlScript script) throws SqlXmlException {
		Class clazz = null;
		
		if ((type != null) && (type.length() > 0)) {
			try {
				clazz = Class.forName(type, true,
					Thread.currentThread().getContextClassLoader());
			}
			catch (Exception e) {
				try {
					clazz = Class.forName(type);
				}
				catch (Exception e2) {
					throw new SqlXmlException("Couldn't load type " + type, e2);
				}
			}
			try {
				script.setProperty(name, ConvertUtils.convert(value, clazz));
			}
			catch (Exception e) {
				throw new SqlXmlException("Couldn't convert [" + value + "] to type "+ type);
			}
		}
		else {
			script.setProperty(getName(), getValue());	
		}
	}

	/**
	 * @return Returns the name.
	 */
	public String getName() {
		return name;
	}
	/**
	 * @param name The name to set.
	 */
	public void setName(String property) {
		this.name = property;
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
	/**
	 * @return Returns the type.
	 */
	public String getType() {
		return type;
	}
	/**
	 * @param type The type to set.
	 */
	public void setType(String type) {
		this.type = type;
	}
}
