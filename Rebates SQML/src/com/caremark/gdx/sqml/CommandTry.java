package com.caremark.gdx.sqml;

import java.sql.SQLException;
import java.util.Collection;
import java.util.Iterator;
import java.util.LinkedList;
import java.util.List;

import org.w3c.dom.Element;
import org.w3c.dom.NodeList;
import org.xml.sax.SAXException;

import com.caremark.gdx.common.util.XMLUtil;

/**
 * @author Bryan Castillo
 *
 */
public class CommandTry extends AbstractXMLCommand {

	private final static org.apache.log4j.Logger logger = org.apache.log4j.Logger
			.getLogger(CommandTry.class.getName());
	
	private List tryCommands;
	private List catchCommands;
	private List finallyCommands;
	
	
	
	/**
	 * @throws Exception
	 * @see com.caremark.gdx.common.IDisposable#dispose()
	 */
	public void dispose() throws Exception {
		super.dispose();
		disposeSubCommands(tryCommands);
		disposeSubCommands(catchCommands);
		disposeSubCommands(finallyCommands);
	}
	
	/**
	 * Dispose all commands in a collection
	 * @param commands
	 * @throws Exception
	 */
	private void disposeSubCommands(Collection commands) throws Exception {
		if (commands != null) {
			for (Iterator i=commands.iterator(); i.hasNext();) {
				((ICommand) i.next()).dispose();
			}
		}
	}
	
	/**
	 * @param element
	 * @throws Exception
	 * @see com.caremark.gdx.common.IXMLInitializable#initialize(org.w3c.dom.Element)
	 */
	public void initialize(Element element) throws Exception {
		NodeList nodes;
		Element subElement;
		String nodeName;
		
		super.initialize(element);
		
		nodes = element.getChildNodes();
		for (int i=0; i<nodes.getLength(); i++) {
			if (nodes.item(i) instanceof Element) {
				subElement = (Element) nodes.item(i);
				nodeName = subElement.getNodeName();
				if (nodeName.equals("try")) {
					parseTry(subElement);
				}
				else if (nodeName.equals("catch")) {
					parseCatch(subElement);
				}
				else if (nodeName.equals("finally")) {
					parseFinally(subElement);
				}
			}
		}
		
	}

	private void parseTry(Element element) throws Exception {
		Element[] nodes;
		if (tryCommands != null) {
			throw new SAXException("Can not have more than 1 try block.");
		}
		tryCommands = new LinkedList();
		nodes = XMLUtil.getElementsByTagName(element, "command");
		for (int i=0; i<nodes.length; i++) {
			tryCommands.add(getScript().parse(ICommand.class, nodes[i]));
		}
	}
	
	private void parseCatch(Element element) throws Exception {
		Element[] nodes;
		if (tryCommands == null) {
			throw new SAXException("catch must come after try.");
		}
		if (finallyCommands != null) {
			throw new SAXException("catch must come before finally.");
		}
		if (catchCommands != null) {
			throw new SAXException("Can not have more than 1 catch block.");
		}
		catchCommands = new LinkedList();
		nodes = XMLUtil.getElementsByTagName(element, "command");
		for (int i=0; i<nodes.length; i++) {
			catchCommands.add(getScript().parse(ICommand.class, nodes[i]));
		}
	}
	
	private void parseFinally(Element element) throws Exception {
		Element[] nodes;
		if (finallyCommands != null) {
			throw new SAXException("Can not have more than 1 finally block.");
		}
		if (tryCommands == null) {
			throw new SAXException("finally must come after try.");
		}
		finallyCommands = new LinkedList();
		nodes = XMLUtil.getElementsByTagName(element, "command");
		for (int i=0; i<nodes.length; i++) {
			finallyCommands.add(getScript().parse(ICommand.class, nodes[i]));
		}
	}
	
	/**
	 * @param script
	 * @throws SqlXmlException
	 * @throws SQLException
	 * @see com.caremark.gdx.sqml.ICommand#execute(com.caremark.gdx.sqml.SqlXmlScript)
	 */
	public void execute(SqlXmlScript script) throws SqlXmlException,
			SQLException
	{
		ICommand command;
		Throwable error;
		try {
			if (tryCommands != null) {
				for (Iterator i=tryCommands.iterator(); i.hasNext();) {
					command = (ICommand) i.next();
					command.execute(script);
				}
			}
		}
		catch (Throwable t) {
			logger.error("execute: caught error in try command - " + t.getMessage(), t);
			script.setError(t);
			if (catchCommands != null) {
				logger.debug("execute: executing catch commands for try command.");
				for (Iterator i=catchCommands.iterator(); i.hasNext();) {
					command = (ICommand) i.next();
					command.execute(script);
				}
			}
			// Allow the script to clear the error
			error = script.getError();
			if (error instanceof SQLException) {
				throw (SQLException) error;
			}
			else if (error instanceof SqlXmlException) {
				throw (SqlXmlException) error;
			}
			else if (error != null) {
				throw new SqlXmlException(error);
			}
		}
		finally {
			if (finallyCommands != null) {
				logger.debug("execute: executing finally commands for try command.");
				for (Iterator i=finallyCommands.iterator(); i.hasNext();) {
					command = (ICommand) i.next();
					command.execute(script);
				}
			}
		}
	}

}
