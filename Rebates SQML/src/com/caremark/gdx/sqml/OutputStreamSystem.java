package com.caremark.gdx.sqml;

import java.io.OutputStream;


/**
 * @author Bryan Castillo
 *
 */
public class OutputStreamSystem implements IOutputStream {

	private String stream = "System.out";

	/**
	 * @throws SqlXmlException
	 * @see com.caremark.gdx.sqml.IOutputStream#finish()
	 */
	public void finish() throws SqlXmlException {
	}
	
	/**
	 * @return
	 * @throws SqlXmlException
	 * @see com.caremark.gdx.sqml.IOutputStream#getOutputStream()
	 */
	public OutputStream getOutputStream() throws SqlXmlException {
		if (stream.equals("System.err")) {
			return System.err;
		}
		else {
			return System.out;
		}
	}
	
	/**
	 * @throws SqlXmlException
	 * @see com.caremark.gdx.sqml.IOutputStream#start()
	 */
	public void start() throws SqlXmlException {
	}
	
	/**
	 * @param script
	 * @throws SqlXmlException
	 * @see com.caremark.gdx.sqml.ISqlXmlObject#onLoad(com.caremark.gdx.sqml.SqlXmlScript)
	 */
	public void onLoad(SqlXmlScript script) throws SqlXmlException {
	}
	
	/**
	 * @return Returns the stream.
	 */
	public String getStream() {
		return stream;
	}

	/**
	 * @param stream The stream to set.
	 */
	public void setStream(String stream) {
		if (!"System.out".equals(stream) && !"System.err".equals(stream)) {
			throw new IllegalArgumentException("stream must be System.out or System.err");
		}
		this.stream = stream;
	}
}
