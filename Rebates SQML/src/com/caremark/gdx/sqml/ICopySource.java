package com.caremark.gdx.sqml;

import java.sql.SQLException;

/**
 * @author Bryan Castillo
 *
 */
public interface ICopySource extends ISqlXmlObject {
	
	/**
	 * Called when the copy command starts executing.
	 * @throws SqlXmlException
	 * @throws SQLException
	 */
	public void start() throws SqlXmlException, SQLException;
	
	/**
	 * Called when the copy command has finished executing
	 * @throws SqlXmlException
	 * @throws SQLException
	 */
	public void finish() throws SqlXmlException, SQLException;
	
	/**
	 * Called after start to retrieve the column labels (if there are any).
	 * @return
	 * @throws SqlXmlException
	 * @throws SQLException
	 */
	public String[] getColumnLabels() throws SqlXmlException, SQLException;
	
	/**
	 * 
	 * @return
	 * @throws SqlXmlException
	 * @throws SQLException
	 */
	public int[] getColumnTypes() throws SqlXmlException, SQLException;
	
	/**
	 * Retrieves one row.
	 * A null value indicates that the source is done.
	 * If there is an empty row an array of 0 elements should be returned.
	 * 
	 * @return
	 * @throws SqlXmlException
	 * @throws SQLException
	 */
	public Object[] getRow() throws SqlXmlException, SQLException;
}
