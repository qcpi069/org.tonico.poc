package com.caremark.gdx.sqml;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.Types;
import java.util.Iterator;
import java.util.*;

import com.caremark.gdx.common.db.ParsedStatement;
import com.caremark.gdx.common.util.StringUtil;

/**
 * @author Bryan Castillo
 *
 */
public class CopyTargetSql extends AbstractXMLCopyTarget {
	
	private final static org.apache.log4j.Logger logger = org.apache.log4j.Logger
			.getLogger(CopyTargetSql.class.getName());
	
	private int queryTimeout = 0;
	private boolean transaction = true;
	private int batch = 0;
	private boolean interpretSql = true;	
	private PreparedStatement preparedStatement;
	private int totalRows = 0;
	private int reportInterval = 5000;
	private Connection connection = null;
	private String ignoredSqlStates = null;
	private Set _ignoredSqlStates = null;

	/**
	 * Method used to see if errors should be ignored such as duplicate key
	 * inserter....
	 * @param sqle
	 * @return
	 */
	protected boolean isExceptionIgnored(SQLException sqle) {
		if (sqle == null) {
			return true;
		}
		boolean result = _ignoredSqlStates.contains(sqle.getSQLState());
		return result;
		
	}
	
	/**
	 * Get the sql to prepare.
	 * 
	 * @return
	 * @throws SqlXmlException
	 * @throws SQLException
	 */
	public String getSql() throws SqlXmlException, SQLException {
		String sql;
		sql = getContent();
		if (isInterpretSql()) {
			sql = getScript().expandProperties(sql);
		}
		return sql;
	}
	
	/**
	 * @throws SqlXmlException
	 * @throws SQLException
	 * @see com.caremark.gdx.sqml.ICopyTarget#start(com.caremark.gdx.sqml.CommandCopy)
	 */
	public void start() throws SqlXmlException, SQLException {
		String[] _ignoredStates;
		String tmp;
		String sql;
		
		sql = getSql();
		logger.warn("start: target sql = " + sql);
		connection = getConnection();
		logger.debug("start: have connection " + connection);
		setPreparedStatement(ParsedStatement.prepare(connection, sql));
		logger.debug("start: prepared statement");
		getScript().setLastStatement(sql);
		logger.debug("start: last statement set");
		
		if (queryTimeout > 0) {
			logger.info("start: setting query timeout to " + queryTimeout);
			getPreparedStatement().setQueryTimeout(queryTimeout);
		}
		

		logger.debug("start: getting ignored SQL states");
		// Prepard code for ignoring certain error conditions
		_ignoredSqlStates = new HashSet();
		String ignoredStates = getIgnoredSqlStates();
		if (ignoredStates != null) {
			_ignoredStates = StringUtil.split(",", ignoredStates);
			for (int i=0; i<_ignoredStates.length; i++) {
				tmp = _ignoredStates[i].trim();
				if (tmp.length() > 0) {
					_ignoredSqlStates.add(tmp);
				}
			}
			if (_ignoredSqlStates.size() > 0) {
				if (getBatch() > 0) {
					logger.warn("start: there are ignored SQL error states which invalidates using batch - setting batch to 0.");
					setBatch(0);
				}
				logger.warn("start: ignoring sql states " + _ignoredSqlStates);
			}
		}
		
		logger.debug("start: start completed");
	}
	

	/**
	 * @throws SqlXmlException
	 * @throws SQLException
	 * @see com.caremark.gdx.sqml.ICopyTarget#finish(com.caremark.gdx.sqml.CommandCopy)
	 */
	public void finish() throws SqlXmlException, SQLException {
		logger.warn("finish: copied " + totalRows + " rows.");
		if (preparedStatement != null) {
			try {
				preparedStatement.close();
			}
			catch (SQLException sqle) {
				logger.error("finish: " + sqle.getMessage(), sqle);
			}
			preparedStatement = null;
		}
		getScript().closeConnection(connection);
		connection = null;
	}

	/**
	 * @param rows
	 * @throws SqlXmlException
	 * @throws SQLException
	 * @see com.caremark.gdx.sqml.ICopyTarget#copyRows(com.caremark.gdx.sqml.CommandCopy, java.util.List)
	 */
	public void copyRows(List rows) throws SqlXmlException,
			SQLException
	{
		int batchCount = 0;
		Connection c = null;
		boolean autoCommit;
		Object[] row;
		int[] columnTypes;
		String[] columnLabels;
		
		if ((rows == null) || (rows.size() == 0)) {
			return;
		}
		
		columnTypes = getColumnTypes();
		columnLabels = getColumnLabels();
		
		c = getConnection();
		autoCommit = c.getAutoCommit();
		try {
			if (transaction) {
				c.setAutoCommit(false);
			}

			// copy rows
			for (Iterator iterator=rows.iterator(); iterator.hasNext();) {
				row = (Object[]) iterator.next();
				try {
					for (int i=0; i<row.length; i++) {
						try {
							if (row[i] == null) {
								if (columnTypes == null) {
									preparedStatement.setNull(i+1, Types.VARCHAR);
								}
								else {
									preparedStatement.setNull(i+1, columnTypes[i]);
								}
							}
							else {
								preparedStatement.setObject(i+1, row[i]);
							}
						}
						catch (SQLException sqle) {
							String lbl = ((columnLabels == null) || (columnLabels[i] == null)) ? "unknown" : columnLabels[i];
							Object val = ((row == null) || (row[i] == null)) ? "unknown" : row[i];
							logger.error("copyRows: couldn't set object [" +
								(i+1) + ":" + lbl + "] [" + val + "]", sqle);
							throw sqle;
						}
					}
					if (batch > 0) {
						preparedStatement.addBatch();
						batchCount++;
						if (batchCount >= batch) {
							logger.debug("copyRows: executing batch");
							preparedStatement.executeBatch();
							batchCount = 0;
						}
					}
					else {
						preparedStatement.execute();
					}
				}
				catch (SQLException sqle) {
					if (!isExceptionIgnored(sqle)) {
						throw sqle;
					}
					else {
						//logger.debug("copyRows: ignoring " + sqle.getMessage());
						if (batchCount > 0) {
							//logger.debug("copyRows: executing batch");
							preparedStatement.executeBatch();
							batchCount = 0;
						}
						// Have to issue commit for some drivers like postgres
						// so that that the state is set back for normal processing.
						if (transaction) {
							//logger.debug("copyRows: commiting due to ignored SQLException [" + totalRows + "]");
							c.commit();
						}
					}
				}
				totalRows++;
				if ((reportInterval > 0) && ((totalRows % reportInterval) == 0)) {
					logger.warn("copyRows: copied " + totalRows + " rows.");
				}
			}
			if (batchCount > 0) {
				//logger.debug("copyRows: executing batch");
				preparedStatement.executeBatch();
				batchCount = 0;
			}

			if (transaction) {
				logger.debug("copyRows: commiting");
				c.commit();
			}
			
		}
		catch (Throwable t) {
			if (transaction) {
				c.rollback();
			}
			if (t instanceof SqlXmlException) {
				throw (SqlXmlException) t;
			}
			else if (t instanceof SQLException) {
				throw (SQLException) t;
			}
			else {
				throw new SqlXmlException(t);
			}
		}
		finally {
			c.setAutoCommit(autoCommit);
		}
	}

	/**
	 * @return Returns the batch.
	 */
	public int getBatch() {
		return batch;
	}
	/**
	 * @param batch The batch to set.
	 */
	public void setBatch(int batchCount) {
		this.batch = batchCount;
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
	 * @return Returns the reportInterval.
	 */
	public int getReportInterval() {
		return reportInterval;
	}
	/**
	 * @param reportInterval The reportInterval to set.
	 */
	public void setReportInterval(int reportInterval) {
		this.reportInterval = reportInterval;
	}
	/**
	 * @return Returns the preparedStatement.
	 */
	protected PreparedStatement getPreparedStatement() {
		return preparedStatement;
	}
	/**
	 * @param preparedStatement The preparedStatement to set.
	 */
	protected void setPreparedStatement(PreparedStatement preparedStatement) {
		this.preparedStatement = preparedStatement;
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
	 * @return Returns the ignoredSqlStates.
	 */
	public String getIgnoredSqlStates() {
		return ignoredSqlStates;
	}
	/**
	 * @param ignoredSqlStates The ignoredSqlStates to set.
	 */
	public void setIgnoredSqlStates(String ignoredSqlStates) {
		this.ignoredSqlStates = ignoredSqlStates;
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
