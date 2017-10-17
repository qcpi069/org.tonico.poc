// Created: Aug 21, 2005    File: SqlXmlTypes.java
package com.caremark.gdx.sqml;

import java.util.HashMap;
import java.util.Map;

/**
 * @author castillo.bryan@gmail.com
 */
public class SqlXmlTypes {

	private HashMap aliases = new HashMap();
	
	public final static Class lookupClass(String className)
		throws ClassNotFoundException
	{
		Class clazz = null;
		try {
			clazz = Class.forName(className);
		}
		catch (ClassNotFoundException cnfe) {
			clazz = Class.forName(
				className,
				true,
				Thread.currentThread().getContextClassLoader());
		}
		return clazz;
	}
	
	public void setTypeAlias(Class interfaceType, String classType, String alias)
		throws SqlXmlException
	{
		try {
			setTypeAlias(interfaceType, lookupClass(classType), alias);
		}
		catch (Exception e) {
			if (e instanceof SqlXmlException) {
				throw (SqlXmlException) e;
			}
			else {
				throw new SqlXmlException(e.getMessage(), e);
			}
		}
	}
	
	public void setTypeAlias(String interfaceType, String classType, String alias)
		throws SqlXmlException
	{
		try {
			setTypeAlias(lookupClass(interfaceType), lookupClass(classType), alias);
		}
		catch (Exception e) {
			if (e instanceof SqlXmlException) {
				throw (SqlXmlException) e;
			}
			else {
				throw new SqlXmlException(e.getMessage(), e);
			}
		}
	}
	
	public void setTypeAlias(Class interfaceType, Class classType,
		String alias)
		throws SqlXmlException
	{
		if (interfaceType == null) {
			throw new SqlXmlException("interfaceType is null.");
		}
		if (classType == null) {
			throw new SqlXmlException("classType is null.");
		}
		if (alias == null) {
			throw new SqlXmlException("alias is null.");
		}
		if (!interfaceType.isAssignableFrom(classType)) {
			throw new SqlXmlException("Can not set type alias [" + alias +
				"] - class type " + classType.getName() +
				" does not implement " + interfaceType.getName());
		}
		
		synchronized (this) {
			Map _types = (Map) aliases.get(interfaceType);
			if (_types == null) {
				_types = new HashMap();
				aliases.put(interfaceType, _types);
			}
			_types.put(alias, classType);
		}
	}
	
	public Object newType(Class interfaceType, String typeName)
		throws Exception
	{
		Class clazz = getType(interfaceType, typeName);
		return clazz.newInstance();
	}
	
	public Class getType(String interfaceType, String typeName)
		throws SqlXmlException
	{
		try {
			return getType(lookupClass(interfaceType), typeName);
		}
		catch (Exception e) {
			throw new SqlXmlException(e);
		}
	}
	
	public Class getType(Class interfaceType, String typeName)
		throws SqlXmlException
	{
		Class clazz = null;
		synchronized (this) {
			Map _types = (Map) aliases.get(interfaceType);
			if (_types != null) {
				clazz = (Class) _types.get(typeName);
			}
		}
		if (clazz == null) {
			try {
				clazz = lookupClass(typeName);
			}
			catch (Exception e) {
				throw new SqlXmlException("Couldn't get type (" + typeName +
					") for " + interfaceType.getName());
			}
			if (!interfaceType.isAssignableFrom(clazz)) {
				throw new SqlXmlException("Type " + typeName +
					" does not implement " + interfaceType.getName());
			}
		}
		return clazz;
	}
}
