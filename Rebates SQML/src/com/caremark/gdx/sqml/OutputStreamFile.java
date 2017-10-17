package com.caremark.gdx.sqml;

import java.io.BufferedOutputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;

/**
 * @author Bryan Castillo
 *
 */
public class OutputStreamFile extends AbstractOutputStream {
	
	private String file;
	private boolean append = false;
	private int bufferSize = 1024 * 4;

	/**
	 * @return
	 * @throws SqlXmlException
	 * @see com.caremark.gdx.sqml.AbstractOutputStream#createOutputStream()
	 */
	public OutputStream createOutputStream() throws SqlXmlException {
		try {
			String _file = getScript().expandProperties(file);
			return new BufferedOutputStream(
				new FileOutputStream(_file, append),
				bufferSize);
		}
		catch (IOException ioe) {
			throw new SqlXmlException(ioe);
		}
	}
	
	/**
	 * @return Returns the append.
	 */
	public boolean isAppend() {
		return append;
	}
	/**
	 * @param append The append to set.
	 */
	public void setAppend(boolean append) {
		this.append = append;
	}
	/**
	 * @return Returns the bufferSize.
	 */
	public int getBufferSize() {
		return bufferSize;
	}
	/**
	 * @param bufferSize The bufferSize to set.
	 */
	public void setBufferSize(int bufferSize) {
		this.bufferSize = bufferSize;
	}
	/**
	 * @return Returns the file.
	 */
	public String getFile() {
		return file;
	}
	/**
	 * @param file The file to set.
	 */
	public void setFile(String file) {
		this.file = file;
	}
}
