package com.caremark.gdx.sqml;

import org.w3c.dom.Element;
import org.xml.sax.SAXException;

import com.caremark.gdx.common.util.XMLUtil;
import java.util.Properties;

/**
 * @author Bryan Castillo
 *
 */
public class DirectiveDatasource extends AbstractXMLDirective {

	private Properties properties;
	private String type;
	private String name;
	
	/**
	 * @param element
	 * @throws Exception
	 * @see com.caremark.gdx.common.IXMLInitializable#initialize(org.w3c.dom.Element)
	 */
	public void initialize(Element element) throws Exception {
		properties = XMLUtil.getProperties(element);
		getScript().expandElementProperties(properties);
		name = (String) properties.get("name");
		type = (String) properties.get("type");
		if (name == null) {
			throw new SAXException("The datasource element should have a name attribute - " + XMLUtil.toString(element));
		}
		if (type == null) {
			throw new SAXException("The datasource element should have a type attribute - " + XMLUtil.toString(element));
		}
		setContent(XMLUtil.getCharacterData(element));
	}
	
	/**
	 * @param script
	 * @throws SqlXmlException
	 * @see com.caremark.gdx.sqml.IDirective#execute(com.caremark.gdx.sqml.SqlXmlScript)
	 */
	public void execute(SqlXmlScript script) throws SqlXmlException {
		script.addDataSource(name, type, properties);
	}

}
