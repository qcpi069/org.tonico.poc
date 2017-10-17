package com.caremark.gdx.sqml;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

public class DirectiveProperties extends AbstractXMLDirective {

	private String resource;
	private boolean ignoreErrors = false;
	
	public void execute(SqlXmlScript script) throws SqlXmlException {
		
		if (resource == null) {
			throw new SqlXmlException("The resource property is mandatory.");
		}
		
		final SqlXmlScript _script = script;
		InputStream in = Thread.currentThread().getContextClassLoader().getResourceAsStream(resource);
		try {
			if (in == null) {
				throw new SqlXmlException("Could not find resource " + resource);
			}
			Properties properties = new Properties() {
				public Object put(Object key, Object value) {
					try {
						// substitue variables
						value = _script.expandProperties(value.toString());
					}
					catch (SqlXmlException sqe) {
					}
					_script.setProperty(key.toString(), value.toString());
					return super.put(key, value);
				}
			};
			properties.load(in);
		}
		catch (Exception e) {
			if (!ignoreErrors) {
				if (e instanceof SqlXmlException) {
					throw (SqlXmlException) e;
				}
				else {
					throw new SqlXmlException(e);
				}
			}
		}
		finally {
			try {
				in.close();
			}
			catch (IOException ioe) {
			}
		}
	}

	public String getResource() {
		return resource;
	}

	public void setResource(String resource) {
		this.resource = resource;
	}

	public boolean isIgnoreErrors() {
		return ignoreErrors;
	}

	public void setIgnoreErrors(boolean ignoreErrors) {
		this.ignoreErrors = ignoreErrors;
	}

}
