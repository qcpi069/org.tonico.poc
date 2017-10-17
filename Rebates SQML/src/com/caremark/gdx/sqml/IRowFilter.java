package com.caremark.gdx.sqml;

/**
 * @author Bryan Castillo
 *
 */
public interface IRowFilter extends ISqlXmlObject {
	
	public String[] getColumnLabels();
	public void setColumnLabels(Object[] row);
	
	public int[] getColumnTypes();
	public void setColumnTypes(int[] types);
	
	public Object[] filter(Object[] row) throws SqlXmlException;
	
}
