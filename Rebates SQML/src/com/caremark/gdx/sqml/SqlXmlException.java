package com.caremark.gdx.sqml;

import org.apache.commons.lang.exception.NestableException;

/**
 * @author Bryan Castillo
 *
 */
public class SqlXmlException extends NestableException {

	/**
	 * 
	 */
	public SqlXmlException() {
		super();
	}

	/**
	 * @param arg0
	 */
	public SqlXmlException(String arg0) {
		super(arg0);
	}

	/**
	 * @param arg0
	 */
	public SqlXmlException(Throwable arg0) {
		super(arg0);
	}

	/**
	 * @param arg0
	 * @param arg1
	 */
	public SqlXmlException(String arg0, Throwable arg1) {
		super(arg0, arg1);
	}

}
