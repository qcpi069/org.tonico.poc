package com.caremark.gdx.sqml;

import java.sql.SQLException;
import java.util.Iterator;
import java.util.LinkedList;
import java.util.List;

import org.w3c.dom.Element;

import com.caremark.gdx.common.util.XMLUtil;

/**
 * @author Bryan Castillo
 *
 */
public class CommandTransaction extends AbstractXMLCommand {

	private final static org.apache.log4j.Logger logger = org.apache.log4j.Logger
			.getLogger(CommandTransaction.class.getName());
	
	private List commands;
	
	/**
	 * @param element
	 * @throws Exception
	 * @see com.caremark.gdx.common.IXMLInitializable#initialize(org.w3c.dom.Element)
	 */
	public void initialize(Element element) throws Exception {
		super.initialize(element);
		Element[] nodes;
		commands = new LinkedList();
		nodes = XMLUtil.getElementsByTagName(element, "command");
		for (int i=0; i<nodes.length; i++) {
			commands.add(getScript().parse(ICommand.class, nodes[i]));
		}
	}
		
	/**
	 * @throws Exception
	 * @see com.caremark.gdx.common.IDisposable#dispose()
	 */
	public void dispose() throws Exception {
		ICommand command;
		for (Iterator i=commands.iterator(); i.hasNext();) {
			command = (ICommand) i.next();
			command.dispose();
		}
		super.dispose();
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
		boolean success = false;
		boolean autoCommit;

		autoCommit = script.isAutoCommit();
		script.setAutoCommit(false);
		
		try {
			for (Iterator i=commands.iterator(); i.hasNext();) {
				command = (ICommand) i.next();
				command.execute(script);
			}
			success = true;
		}
		finally {
			script.setAutoCommit(autoCommit);
			if (!success) {
				// There is a relevant exception already being thrown
				// Don't let the rollback exception hide it.
				try {
					script.rollbackAll();
				}
				catch (SQLException sqle) {
					logger.error("execute: " + sqle.getMessage(), sqle);
				}
			}
			else {
				script.commitAll(true);
			}
		}
	}

}
