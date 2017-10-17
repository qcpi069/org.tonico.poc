package com.caremark.gdx.sqml;

/**
 * @author Bryan Castillo
 *
 */
public class DirectiveDatasources extends AbstractXMLDirective {

	private String resource = null;
	
	/**
	 * @param script
	 * @throws SqlXmlException
	 * @see com.caremark.gdx.sqml.IDirective#execute(com.caremark.gdx.sqml.SqlXmlScript)
	 */
	public void execute(SqlXmlScript script) throws SqlXmlException {
		if (resource == null) {
			script.setDataSourceRegistryResourceToDefault();
		}
		else {
			script.setDataSourceRegistryResource(resource);
		}
	}

	public String getResource() {
		return resource;
	}

	public void setResource(String resource) {
		this.resource = resource;
	}

}
