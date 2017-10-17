package com.caremark.gdx.sqml;

import java.sql.SQLException;

import com.caremark.gdx.common.IDisposable;

/**
 * @author Bryan Castillo
 *
 */
public interface ICommand extends IDisposable, ISqlXmlObject {
	public void execute(SqlXmlScript script) throws SqlXmlException, SQLException;
}
