package com.caremark.gdx.sqml;

import java.io.IOException;
import java.io.OutputStream;

/**
 * @author Bryan Castillo
 *
 */
public class OutputDelegate extends OutputStream {

	private OutputStream output;
	
	public OutputDelegate(OutputStream output) {
		this.output = output;
	}

	
	
	/**
	 * @throws java.lang.Throwable
	 * @see java.lang.Object#finalize()
	 */
	protected void finalize() throws Throwable {
		System.err.println("finalize: " + output);
		super.finalize();
	}
	
	/**
	 * @throws java.io.IOException
	 */
	public void close() throws IOException {
		System.err.println("close: " + output);
		output.close();
	}
	/**
	 * @param obj
	 * @return
	 * @see java.lang.Object#equals(java.lang.Object)
	 */
	public boolean equals(Object obj) {
		return output.equals(obj);
	}
	/**
	 * @throws java.io.IOException
	 */
	public void flush() throws IOException {
		System.err.println("flush: " + output);
		output.flush();
	}
	/**
	 * @return
	 * @see java.lang.Object#hashCode()
	 */
	public int hashCode() {
		return output.hashCode();
	}
	/**
	 * @return
	 * @see java.lang.Object#toString()
	 */
	public String toString() {
		return output.toString();
	}
	/**
	 * @param b
	 * @throws java.io.IOException
	 */
	public void write(byte[] b) throws IOException {
		System.err.println("write(byte[] b): " + output);
		output.write(b);
	}
	/**
	 * @param b
	 * @param off
	 * @param len
	 * @throws java.io.IOException
	 */
	public void write(byte[] b, int off, int len) throws IOException {
		System.err.println("write(byte[] b, int off, int len): " + output);
		output.write(b, off, len);
	}
	/**
	 * @param b
	 * @throws java.io.IOException
	 */
	public void write(int b) throws IOException {
		System.err.println("write(int b): " + output);
		output.write(b);
	}
}
