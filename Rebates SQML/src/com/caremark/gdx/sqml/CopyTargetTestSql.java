package com.caremark.gdx.sqml;

import java.sql.SQLException;
import java.util.List;

import org.w3c.dom.Element;
import org.xml.sax.SAXException;

import com.caremark.gdx.common.util.XMLUtil;

/**
 * @author Bryan Castillo
 *
 */
public class CopyTargetTestSql extends AbstractXMLCopyTarget {

	private ICopyTarget subTarget = null;

	/**
	 * @param element
	 * @throws Exception
	 * @see com.caremark.gdx.common.IXMLInitializable#initialize(org.w3c.dom.Element)
	 */
	public void initialize(Element element) throws Exception {
		Element[] nodes;
		
		super.initialize(element);
		nodes = XMLUtil.getElementsByTagName(element, "target");
		if (nodes.length != 1) {
			throw new SAXException("There should only be 1 sub target");
		}
		subTarget = (ICopyTarget) getScript().parse(ICopyTarget.class, nodes[0]);

		nodes = XMLUtil.getElementsByTagName(element, "test");
		if (nodes.length != 1) {
			throw new SAXException("There should only be 1 test element");
		}
		XMLUtil.getCharacterData(nodes[0]);
		
	}
	
	/**
	 * @throws SqlXmlException
	 * @throws SQLException
	 * @see com.caremark.gdx.sqml.ICopyTarget#start()
	 */
	public void start() throws SqlXmlException, SQLException {
		subTarget.start();
	}

	/**
	 * @param rows
	 * @throws SqlXmlException
	 * @throws SQLException
	 * @see com.caremark.gdx.sqml.ICopyTarget#copyRows(java.util.List)
	 */
	public void copyRows(List rows) throws SqlXmlException, SQLException {
	}

}
