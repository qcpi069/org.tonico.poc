package com.caremark.gdx.sqml;

import java.sql.SQLException;
import java.util.List;

/**
 * @author Bryan Castillo
 *
 */
public interface ICopyTarget extends ISqlXmlObject {
	
	/**
	 * Called when the copy command actually executes.
	 * @throws SqlXmlException
	 * @throws SQLException
	 */
	public void start() throws SqlXmlException, SQLException;
	
	/**
	 * Last method called when copy command has completed.
	 * @throws SqlXmlException
	 * @throws SQLException
	 */
	public void finish() throws SqlXmlException, SQLException;
	
	/**
	 * Called right before start.
	 * The target may want to print column headers to a file
	 * or use them for mapping the rows by name.
	 * 
	 * @param columnLabels
	 * @throws SqlXmlException
	 * @throws SQLException
	 */
	public void setColumnLabels(String[] columnLabels) throws SqlXmlException, SQLException;

	public void setColumnTypes(int [] columnTypes);
	
	/**
	 * Method is called as rows are fetched from the source.
	 * There may be 0 to N rows.
	 * An implementation may use the multiple rows to have all inserted
	 * as a batch or in 1 transaction.
	 * 
	 * @param rows Will contain a List of Object[]'s
	 * @throws SqlXmlException
	 * @throws SQLException
	 */
	public void copyRows(List rows) throws SqlXmlException, SQLException;
}
