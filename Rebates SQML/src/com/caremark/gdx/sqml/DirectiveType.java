package com.caremark.gdx.sqml;

/**
 * @author Bryan Castillo
 *
 */
public class DirectiveType extends AbstractXMLDirective {

	private String interfaceType;
	private String classType;
	private String name;
	
	/**
	 * @param script
	 * @throws SqlXmlException
	 * @see com.caremark.gdx.sqml.IDirective#execute(com.caremark.gdx.sqml.SqlXmlScript)
	 */
	public void execute(SqlXmlScript script) throws SqlXmlException {
		script.setType(getInterfaceType(), getClassType(), getName());
	}

	/**
	 * @return Returns the classType.
	 */
	public String getClassType() {
		return classType;
	}
	/**
	 * @param classType The classType to set.
	 */
	public void setClassType(String classType) {
		this.classType = classType;
	}
	/**
	 * @return Returns the interfaceType.
	 */
	public String getInterfaceType() {
		return interfaceType;
	}
	/**
	 * @param interfaceType The interfaceType to set.
	 */
	public void setInterfaceType(String interfaceType) {
		this.interfaceType = interfaceType;
	}
	/**
	 * @return Returns the name.
	 */
	public String getName() {
		return name;
	}
	/**
	 * @param name The name to set.
	 */
	public void setName(String name) {
		this.name = name;
	}
}
