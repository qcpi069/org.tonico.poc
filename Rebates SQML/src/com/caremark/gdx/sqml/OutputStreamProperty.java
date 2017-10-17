package com.caremark.gdx.sqml;

import java.io.ByteArrayOutputStream;
import java.io.OutputStream;

/**
 * @author Bryan Castillo
 *
 */
public class OutputStreamProperty extends AbstractOutputStream {
	
	private String property;
	
	/**
	 * @return
	 * @throws SqlXmlException
	 * @see com.caremark.gdx.sqml.AbstractOutputStream#createOutputStream()
	 */
	public OutputStream createOutputStream() throws SqlXmlException {
		return new ByteArrayOutputStream();
	}

	/**
	 * @throws SqlXmlException
	 * @see com.caremark.gdx.sqml.IOutputStream#finish()
	 */
	public void finish() throws SqlXmlException {
		System.err.println("finishing...............");
		ByteArrayOutputStream out = (ByteArrayOutputStream) getOutputStream();
		String value = out.toString();
		System.err.println(getScript());
		System.err.println("---------------------------------");
		System.err.println("Setting property [" + property + "]");
		getScript().setProperty(property, value);
		System.err.println("---------------------------------");
		System.err.println(getScript());
		super.finish();
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
