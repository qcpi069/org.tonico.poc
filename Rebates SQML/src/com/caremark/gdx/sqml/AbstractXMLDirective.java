package com.caremark.gdx.sqml;

import org.w3c.dom.Element;

import com.caremark.gdx.common.IXMLInitializable;
import com.caremark.gdx.common.util.XMLUtil;

/**
 * @author Bryan Castillo
 *
 */
public abstract class AbstractXMLDirective implements IDirective, IXMLInitializable
{

	private SqlXmlScript script;
	private String content;
	
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
	 * @param script
	 * @throws SqlXmlException
	 * @see com.caremark.gdx.sqml.ISqlXmlObject#onLoad(com.caremark.gdx.sqml.SqlXmlScript)
	 */
	public void onLoad(SqlXmlScript script) throws SqlXmlException {
		this.script = script;
	}

	
	/**
	 * @return
	 */
	public String getContent() {
		return content;
	}
	
	/**
	 * 
	 * @param content
	 */
	public void setContent(String content) {
		this.content = content;
	}
	
	/**
	 * @return
	 */
	public SqlXmlScript getScript() {
		return script;
	}
}
