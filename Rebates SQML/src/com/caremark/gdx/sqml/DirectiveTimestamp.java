package com.caremark.gdx.sqml;

import java.text.SimpleDateFormat;
import java.util.Date;

import com.caremark.gdx.common.util.StringUtil;

/**
 * @author Bryan Castillo
 *
 */
public class DirectiveTimestamp extends AbstractXMLDirective {

	private String property = "time";
	private String format = null;

	/**
	 * @param script
	 * @throws SqlXmlException
	 * @see com.caremark.gdx.sqml.IDirective#execute(com.caremark.gdx.sqml.SqlXmlScript)
	 */
	public void execute(SqlXmlScript script) throws SqlXmlException
	{
		try {
			String value = null;
			if (StringUtil.isEmpty(format)) {
				value = new Date().toString();
			}
			else {
				SimpleDateFormat sdf = new SimpleDateFormat(getFormat());
				value = sdf.format(new Date());
			}
			script.setProperty(property, value);
		}
		catch (Exception e) {
			throw new SqlXmlException(e);
		}
	}

	/**
	 * @return Returns the format.
	 */
	public String getFormat() {
		return format;
	}
	/**
	 * @param format The format to set.
	 */
	public void setFormat(String format) {
		this.format = format;
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
}
