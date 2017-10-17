package com.caremark.gdx.sqml;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.StringReader;
import java.sql.SQLException;
import java.sql.Connection;
import java.util.ArrayList;

import com.caremark.gdx.common.util.StringUtil;

/**
 * @author Bryan Castillo
 *
 */
public class CommandRun extends AbstractXMLCommand {

	private final static org.apache.log4j.Logger logger = org.apache.log4j.Logger
			.getLogger(CommandRun.class.getName());
	
	private int queryTimeout = 0;
	private boolean substitueParameters = true;
	private boolean interpretSql = true;
	private String delimiter = ";";
	private boolean transaction = false;
	private String rowName = "row";
	
	/**
	 * Get the sql statements.
	 * 
	 * @return
	 * @throws SqlXmlException
	 */
	private String[] getStatements() throws SqlXmlException {
		try {
			String[] statements = null;
			String sqlContent = getContent();
			if ((delimiter == null) || (delimiter.length() == 0)) {
				if (StringUtil.isEmpty(sqlContent)) {
					statements = new String[0];
				}
				else {
					statements = new String[] { sqlContent };
				}
			}
			else {
				ArrayList _statements = new ArrayList();
				BufferedReader in = new BufferedReader(new StringReader(sqlContent));
				String line = null;
				StringBuffer sb = new StringBuffer();
				String statement = null;
	
				while ((line = in.readLine()) != null) {
					int pos = line.lastIndexOf(getDelimiter());
					if ((pos >= 0) && (line.trim().endsWith(getDelimiter()))) {
						sb.append(line.substring(0, pos));
						statement = sb.toString();
						if (!StringUtil.isEmpty(statement)) {
							_statements.add(statement);
						}
						sb = new StringBuffer();
					}
					else {
						sb.append(line);
					}
				}
				
				// Add remaining statement
				statement = sb.toString();
				if (!StringUtil.isEmpty(statement)) {
					_statements.add(statement);
				}
				
				statements = (String[]) _statements.toArray(new String[_statements.size()]);
				in.close();
			}
			return statements;
		}
		catch (IOException ioe) {
			throw new SqlXmlException(ioe);
		}
	}

	/**
	 * @param script
	 * @throws SqlXmlException
	 * @see com.caremark.gdx.sqml.ICommand#execute(com.caremark.gdx.sqml.SqlXmlScript)
	 */
	public void execute(SqlXmlScript script)
		throws SqlXmlException, SQLException
	{
		String sql;
		Connection c = null;
		boolean autoCommit = false;
		boolean success = false;
		String[] statements;
		
		statements = getStatements();
		c = getConnection();
		try {
			if (transaction) {
				autoCommit = c.getAutoCommit();
				c.setAutoCommit(false);
			}
			for (int i=0; i<statements.length; i++) {
				sql = statements[i];
				if (interpretSql) {
					sql = script.expandProperties(sql);
				}
				logger.info("execute: [" + sql + "]");		
				script.runStatement(c, sql, substitueParameters, rowName, queryTimeout);
				logger.info("execute: statement complete");
			}
			success = true;
		}
		finally {
			if ((transaction) && (c != null)) {
				if (!success) {
					c.rollback();
				}
				c.setAutoCommit(autoCommit);
			}
			logger.info("execute: complete");	
		}
	}

	/**
	 * @return Returns the delimiter.
	 */
	public String getDelimiter() {
		return delimiter;
	}
	/**
	 * @param delimiter The delimiter to set.
	 */
	public void setDelimiter(String delimiter) {
		this.delimiter = delimiter;
	}
	/**
	 * @return Returns the interpretSql.
	 */
	public boolean isInterpretSql() {
		return interpretSql;
	}
	/**
	 * @param interpretSql The interpretSql to set.
	 */
	public void setInterpretSql(boolean interpretSql) {
		this.interpretSql = interpretSql;
	}

	/**
	 * @return Returns the substitueParameters.
	 */
	public boolean isSubstitueParameters() {
		return substitueParameters;
	}
	/**
	 * @param substitueParameters The substitueParameters to set.
	 */
	public void setSubstitueParameters(boolean substitueParameters) {
		this.substitueParameters = substitueParameters;
	}
	/**
	 * @return Returns the transaction.
	 */
	public boolean isTransaction() {
		return transaction;
	}
	/**
	 * @param transaction The transaction to set.
	 */
	public void setTransaction(boolean transaction) {
		this.transaction = transaction;
	}
	/**
	 * @return Returns the rowName.
	 */
	public String getRowName() {
		return rowName;
	}
	/**
	 * @param rowName The rowName to set.
	 */
	public void setRowName(String rowName) {
		this.rowName = rowName;
	}
	/**
	 * @return Returns the queryTimeout.
	 */
	public int getQueryTimeout() {
		return queryTimeout;
	}
	/**
	 * @param queryTimeout The queryTimeout to set.
	 */
	public void setQueryTimeout(int queryTimeout) {
		this.queryTimeout = queryTimeout;
	}
}
