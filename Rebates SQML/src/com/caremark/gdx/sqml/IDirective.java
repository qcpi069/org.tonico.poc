package com.caremark.gdx.sqml;

/**
 * @author Bryan Castillo
 *
 */
public interface IDirective extends ISqlXmlObject {
	public void execute(SqlXmlScript script) throws SqlXmlException;
}
