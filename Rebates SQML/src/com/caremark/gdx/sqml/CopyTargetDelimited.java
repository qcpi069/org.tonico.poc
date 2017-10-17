// Created: Aug 21, 2005    File: CopyTargetDelimited.java
package com.caremark.gdx.sqml;

import java.io.IOException;
import java.io.OutputStream;
import java.sql.SQLException;
import java.util.Iterator;
import java.util.List;

import org.apache.commons.lang.StringEscapeUtils;
import org.w3c.dom.Element;

import com.caremark.gdx.common.util.StringUtil;
import com.caremark.gdx.common.util.XMLUtil;

/**
 * @author castillo.bryan@gmail.com
 */
public class CopyTargetDelimited extends AbstractXMLCopyTarget {
	
	private String recordSeparator = System.getProperty("line.separator", "\n");
	private String fieldSeparator = ",";
	private String quote = "\"";
	private boolean printHeader = true;
	private IOutputStream output;
	
	/**
	 * @param element
	 * @throws Exception
	 * @see com.caremark.gdx.common.IXMLInitializable#initialize(org.w3c.dom.Element)
	 */
	public void initialize(Element element) throws Exception {
		super.initialize(element);
		Element[] nodes = XMLUtil.getElementsByTagName(element, "output");
		switch (nodes.length) {
			case 0:
				throw new SqlXmlException("There must be an output element for a delimted target.");
			case 1:
				break;
			default:
				throw new SqlXmlException("There should be only 1 output element for a delimted target.");
		}
		output = (IOutputStream) getScript().parse(IOutputStream.class, nodes[0]);
	}
	
	/**
	 * @throws SqlXmlException
	 * @throws SQLException
	 * @see com.caremark.gdx.sqml.ICopyTarget#start()
	 */
	public void start() throws SqlXmlException, SQLException {
		OutputStream out;
		String[] labels;
		StringBuffer sb;
		
		output.start();
		if (isPrintHeader()) {
			out = output.getOutputStream();
			labels = getColumnLabels();
			if (labels != null) {
				sb = new StringBuffer(128);
				for (int i=0; i<labels.length; i++) {
					if ((i > 0) && (fieldSeparator != null)) {
						sb.append(fieldSeparator);
					}
					if (labels[i] != null) {
						sb.append(escapeField(labels[i].toString()));
					}
				}
				if (recordSeparator != null) {
					sb.append(recordSeparator);
				}
				try {
					out.write(sb.toString().getBytes());
				}
				catch (IOException ioe) {
					System.err.println("io exception");
					throw new SqlXmlException(ioe);
				}
			}
		}
	}

	/**
	 * @throws SqlXmlException
	 * @throws SQLException
	 * @see com.caremark.gdx.sqml.ICopyTarget#finish()
	 */
	public void finish() throws SqlXmlException, SQLException {
		output.finish();
		super.finish();
	}

	/**
	 * @param rows
	 * @throws SqlXmlException
	 * @throws SQLException
	 * @see com.caremark.gdx.sqml.ICopyTarget#copyRows(java.util.List)
	 */
	public void copyRows(List rows) throws SqlXmlException, SQLException {
		OutputStream out;
		if ((rows == null) || (rows.size() == 0)) {
			return;
		}
		out = output.getOutputStream();
		for (Iterator iterator=rows.iterator(); iterator.hasNext();) {
			Object[] row = (Object[]) iterator.next();
			StringBuffer sb = new StringBuffer();
			for (int i=0; i<row.length; i++) {
				if ((i > 0) && (fieldSeparator != null)) {
					sb.append(fieldSeparator);
				}
				if (row[i] != null) {
					sb.append(escapeField(row[i].toString()));
				}
			}
			if (recordSeparator != null) {
				sb.append(recordSeparator);
			}
			try {
				out.write(sb.toString().getBytes());
			}
			catch (IOException ioe) {
				System.err.println("io exception");
				throw new SqlXmlException(ioe);
			}
		}
	}

	
	/**
	 * Escapes a field.
	 * If a quote character is set it will look through the string
	 * and add quotes if there are literal quotes, field separators or new lines
	 * in the input string.  If a quote is found in the string another quote
	 * is added right before it.  This is how Excel escapes "'s in literal input
	 * for its CSV format.
	 * 
	 * @param field
	 * @return
	 */
	private String escapeField(Object field) {
		StringBuffer sb = new StringBuffer();
		String _field;
		char c;
		int pos;
		boolean needQuote = false;
		char _quote = 0;
		char _fieldSeparator = 0;
		boolean quotable = false;
		
		if (field == null) {
			return "";
		}
		_field = field.toString();
		
		if (StringUtil.isEmpty(quote)) {
			return _field;
		}
		_quote = quote.charAt(0);
		quotable = true;
		
		if (!StringUtil.isEmpty(fieldSeparator)) {
			_fieldSeparator = fieldSeparator.charAt(0);
		}
		
		for (pos=0; pos<_field.length(); pos++) {
			c = _field.charAt(pos);
			if (quotable) {
				if ((c == '\r') || (c == '\n') ||
					((_fieldSeparator != 0) && (_fieldSeparator == c)))
				{
					needQuote = true;
				}
				else if ((_quote != 0) && (_quote == c)) {
					sb.append(quote);
					needQuote = true;
				}
			}
			sb.append(c);
		}
		
		if (needQuote) {
			return quote + sb + quote;
		}
		else {
			return sb.toString();
		}
	}
	
	
	/**
	 * @return Returns the fieldSeparator.
	 */
	public String getFieldSeparator() {
		return fieldSeparator;
	}
	/**
	 * @param fieldSeparator The fieldSeparator to set.
	 */
	public void setFieldSeparator(String fieldSeparator) {
		this.fieldSeparator = StringEscapeUtils.unescapeJava(fieldSeparator);
	}
	/**
	 * @return Returns the printHeader.
	 */
	public boolean isPrintHeader() {
		return printHeader;
	}
	/**
	 * @param printHeader The printHeader to set.
	 */
	public void setPrintHeader(boolean printHeader) {
		this.printHeader = printHeader;
	}
	/**
	 * @return Returns the quote.
	 */
	public String getQuote() {
		return quote;
	}
	/**
	 * @param quote The quote to set.
	 */
	public void setQuote(String quote) {
		this.quote = quote;
	}
	/**
	 * @return Returns the recordSeparator.
	 */
	public String getRecordSeparator() {
		return recordSeparator;
	}
	/**
	 * @param recordSeparator The recordSeparator to set.
	 */
	public void setRecordSeparator(String recordSeparator) {
		this.recordSeparator = StringEscapeUtils.unescapeJava(recordSeparator);
	}
}
