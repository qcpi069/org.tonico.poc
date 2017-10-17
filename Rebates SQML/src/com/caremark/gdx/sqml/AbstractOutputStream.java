package com.caremark.gdx.sqml;

import java.io.IOException;
import java.io.OutputStream;

import org.w3c.dom.Element;

import com.caremark.gdx.common.IXMLInitializable;
import com.caremark.gdx.common.util.XMLUtil;

/**
 * @author Bryan Castillo
 *
 */
public abstract class AbstractOutputStream implements IOutputStream, IXMLInitializable {

	private final static org.apache.log4j.Logger logger = org.apache.log4j.Logger
			.getLogger(AbstractOutputStream.class.getName());
	
	private SqlXmlScript script;
	private OutputStream output;
	private String content;
	
	public abstract OutputStream createOutputStream() throws SqlXmlException; 
	
	/**
	 * @param element
	 * @throws Exception
	 * @see com.caremark.gdx.common.IXMLInitializable#initialize(org.w3c.dom.Element)
	 */
	public void initialize(Element element) throws Exception {
		getScript().applyElementProperties(this, element);
		content = XMLUtil.getCharacterData(element);
	}

	/**
	 * @throws SqlXmlException
	 * @see com.caremark.gdx.sqml.IOutputStream#start()
	 */
	public void start() throws SqlXmlException {
		clear();
		getOutputStream();
	}

	/**
	 * @return
	 * @throws SqlXmlException
	 * @see com.caremark.gdx.sqml.IOutputStream#getOutputStream()
	 */
	public OutputStream getOutputStream() throws SqlXmlException {
		if (output == null) {
			output = createOutputStream();
		}
		return output;
	}

	/**
	 * @throws SqlXmlException
	 * @see com.caremark.gdx.sqml.IOutputStream#finish()
	 */
	public void finish() throws SqlXmlException {
		clear();
	}

	/**
	 * @param script
	 * @throws SqlXmlException
	 * @see com.caremark.gdx.sqml.ISqlXmlObject#onLoad(com.caremark.gdx.sqml.SqlXmlScript)
	 */
	public void onLoad(SqlXmlScript script) throws SqlXmlException {
		this.script = script;
	}
	
	/**
	 * Gets the SqlXmlScript
	 * @return
	 */
	public SqlXmlScript getScript() {
		return script;
	}

	/**
	 * Closes the output stream
	 *
	 */
	protected void clear() {
		if (output != null) {
			try {
				logger.debug("clear: output = " + output);
				output.close();
			}
			catch (IOException ioe) {
				logger.error("clear: " + ioe.getMessage(), ioe);
			}
			output = null;
		}
	}
	/**
	 * @return Returns the content.
	 */
	public String getContent() {
		return content;
	}
	/**
	 * @param content The content to set.
	 */
	public void setContent(String content) {
		this.content = content;
	}
}
