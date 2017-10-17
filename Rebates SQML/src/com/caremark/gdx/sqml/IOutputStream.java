// Created: Aug 21, 2005    File: IOutputStream.java
package com.caremark.gdx.sqml;

import java.io.OutputStream;

/**
 * @author castillo.bryan@gmail.com
 */
public interface IOutputStream extends ISqlXmlObject {
	public void start() throws SqlXmlException;
	public OutputStream getOutputStream() throws SqlXmlException;
	public void finish() throws SqlXmlException;
}
