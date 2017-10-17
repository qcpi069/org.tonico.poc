// Created: Aug 18, 2005    File: CommandJava.java
package com.caremark.gdx.sqml;

import java.sql.Connection;
import java.util.Collection;
import java.util.Iterator;
import java.util.LinkedList;

import bsh.Interpreter;
import bsh.TargetError;

/**
 * @author castillo.bryan@gmail.com
 */
public class CommandJava extends AbstractXMLCommand {

	private final static org.apache.log4j.Logger logger = org.apache.log4j.Logger
			.getLogger(CommandJava.class.getName());
	
	public String getBSHScript() {
		return getContent();
	}
	
	/**
	 * @param script
	 * @throws SqlXmlException
	 * @see com.caremark.gdx.sqml.ICommand#execute(com.caremark.gdx.sqml.SqlXmlScript)
	 */
	public void execute(SqlXmlScript script) throws SqlXmlException {
		Collection connections = new LinkedList();
		try {
			Interpreter interpreter = new Interpreter();
			interpreter.set("script", script);
			interpreter.set("command", this);
			interpreter.set("logger", logger);
			interpreter.eval("setAccessibility(true)");
			interpreter.eval(getBSHScript());
		}
		catch (TargetError te) {
			if (te.getTarget() != null) {
				throw new SqlXmlException(te.getTarget());
			}
			else {
				throw new SqlXmlException(te);
			}
		}
		catch (Exception e) {
			throw new SqlXmlException(e);
		}
		finally {
			for (Iterator i=connections.iterator(); i.hasNext();) {
				getScript().closeConnection((Connection) i.next());
			}
		}
	}

}
