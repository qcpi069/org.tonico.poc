package com.caremark.gdx.sqml;

import java.io.IOException;
import java.io.OutputStream;
import java.util.zip.GZIPOutputStream;

import org.w3c.dom.Element;

import com.caremark.gdx.common.util.XMLUtil;

/**
 * @author Bryan Castillo
 *
 */
public class OutputStreamGzip extends AbstractOutputStream {

	private IOutputStream childOutput;
	
	/**
	 * @param element
	 * @throws Exception
	 * @see com.caremark.gdx.common.IXMLInitializable#initialize(org.w3c.dom.Element)
	 */
	public void initialize(Element element) throws Exception {
		super.initialize(element);
		Element[] nodes = XMLUtil.getElementsByTagName(element, "output");
		switch (nodes.length) {
			case 0:
				throw new SqlXmlException("There must be an output element for a gzip target.");
			case 1:
				break;
			default:
				throw new SqlXmlException("There should be only 1 output element for a gzip target.");
		}
		childOutput = (IOutputStream) getScript().parse(IOutputStream.class, nodes[0]);
	}

	/**
	 * @throws SqlXmlException
	 * @see com.caremark.gdx.sqml.IOutputStream#finish()
	 */
	public void finish() throws SqlXmlException {
		System.err.println("finishing gzip");
		super.finish();
		childOutput.finish();
	}
	
	/**
	 * @throws SqlXmlException
	 * @see com.caremark.gdx.sqml.IOutputStream#start()
	 */
	public void start() throws SqlXmlException {
		childOutput.start();
		super.start();
	}
	
	/**
	 * @return
	 * @throws SqlXmlException
	 * @see com.caremark.gdx.sqml.AbstractOutputStream#createOutputStream()
	 */
	public OutputStream createOutputStream() throws SqlXmlException {
		try {
			OutputStream child = childOutput.getOutputStream();
			return new GZIPOutputStream(child);
		}
		catch (IOException ioe) {
			throw new SqlXmlException(ioe);
		}
	}
}
