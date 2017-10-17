package com.caremark.gdx.sqml;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.InetAddress;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.Properties;

import javax.sql.DataSource;
import javax.xml.parsers.DocumentBuilderFactory;

import org.apache.commons.lang.StringEscapeUtils;
import org.apache.log4j.PropertyConfigurator;
import org.apache.log4j.xml.DOMConfigurator;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.xml.sax.SAXException;

import com.caremark.gdx.common.IDisposable;
import com.caremark.gdx.common.IXMLInitializable;
import com.caremark.gdx.common.db.DBException;
import com.caremark.gdx.common.db.DataSourceRegistry;
import com.caremark.gdx.common.db.DataSources;
import com.caremark.gdx.common.db.ParsedStatement;
import com.caremark.gdx.common.os.Environment;
import com.caremark.gdx.common.util.ExceptionUtil;
import com.caremark.gdx.common.util.InitializeUtil;
import com.caremark.gdx.common.util.ResourceUtil;
import com.caremark.gdx.common.util.StringUtil;
import com.caremark.gdx.common.util.TemplateUtil;
import com.caremark.gdx.common.util.XMLUtil;

/**
 * @author Bryan Castillo
 *
 */
public class SqlXmlScript implements IDisposable {

	private static org.apache.log4j.Logger logger = org.apache.log4j.Logger
			.getLogger(SqlXmlScript.class.getName());
	
	private DataSourceRegistry dsRegistry = null;
	private Map properties = new HashMap();
	private List commands = new LinkedList();
	private SqlXmlTypes types = new SqlXmlTypes();
	private Map connections = new HashMap();
	private boolean autoCommit = true;
	private String lastStatement;
	
	public SqlXmlScript() throws SqlXmlException {
		
		// Directives
		types.setTypeAlias(IDirective.class, DirectiveTimestamp.class, "timestamp");
		types.setTypeAlias(IDirective.class, DirectiveProperty.class, "property");
		types.setTypeAlias(IDirective.class, DirectiveProperties.class, "properties");
		types.setTypeAlias(IDirective.class, DirectiveType.class, "type");
		types.setTypeAlias(IDirective.class, DirectiveDatasource.class, "datasource");
		types.setTypeAlias(IDirective.class, DirectiveDatasources.class, "datasources");
		
		// Commands
		types.setTypeAlias(ICommand.class, CommandRun.class, "run");
		types.setTypeAlias(ICommand.class, CommandJava.class, "java");
		types.setTypeAlias(ICommand.class, CommandCopy.class, "copy");
		types.setTypeAlias(ICommand.class, CommandTry.class, "try");
		types.setTypeAlias(ICommand.class, CommandSet.class, "set");
		types.setTypeAlias(ICommand.class, CommandTransaction.class, "transaction");
		types.setTypeAlias(ICommand.class, CommandMail.class, "mail");
		types.setTypeAlias(ICommand.class, CommandFtp.class, "ftp");

		//Copy Sources & Targets
		types.setTypeAlias(ICopySource.class, CopySourceSql.class, "sql");
		types.setTypeAlias(ICopyTarget.class, CopyTargetSql.class, "sql");
		types.setTypeAlias(ICopyTarget.class, CopyTargetTable.class, "table");
		types.setTypeAlias(ICopyTarget.class, CopyTargetDelimited.class, "delimited");
		types.setTypeAlias(ICopyTarget.class, CopyTargetQueue.class, "queue");
		
		//Output Types
		types.setTypeAlias(IOutputStream.class, OutputStreamFile.class, "file");
		types.setTypeAlias(IOutputStream.class, OutputStreamGzip.class, "gzip");
		types.setTypeAlias(IOutputStream.class, OutputStreamProperty.class, "property");
		types.setTypeAlias(IOutputStream.class, OutputStreamSystem.class, "system");

		// Set localhost property
		String localhost = "localhost";
		try {
			localhost = InetAddress.getLocalHost().getHostName();
		}
		catch (Exception e) {
		}
		setProperty("localhost", localhost);
	}
	
	/* PUBLIC METHODS ------------------------------------------------------- */

	public DataSourceRegistry getDataSourceRegistry() {
		synchronized (this) {
			if (dsRegistry == null) {
				dsRegistry = new DataSourceRegistry();
			}
			return dsRegistry;
		}
	}
	
	public void setDataSourceRegistry(DataSourceRegistry dsRegistry) {
		synchronized (this) {
			this.dsRegistry = dsRegistry;
		}
	}
	
	public void addDataSource(String name, String type, Properties properties)
		throws SqlXmlException
	{
		try {
			synchronized (this) {
				getDataSourceRegistry().addDataSource(name, type, properties);
			}
		}
		catch (DBException dbe) {
			throw new SqlXmlException(dbe);
		}
	}
	
	public void setDataSourceRegistryResourceToDefault() throws SqlXmlException {
		try {
			setDataSourceRegistry(DataSources.getDataSourceCache());
		}
		catch (DBException dbe) {
			throw new SqlXmlException(dbe);
		}
	}
	
	public void setDataSourceRegistryResource(String resource)
		throws SqlXmlException
	{
		try {
			setDataSourceRegistry(DataSourceRegistry.newInstance(resource));
		}
		catch (DBException dbe) {
			throw new SqlXmlException(dbe);
		}
	}
	
	public void setType(String interfaceType, String classType, String typeName)
		throws SqlXmlException
	{
		types.setTypeAlias(interfaceType, classType, typeName);
	}
	
	public Class getType(String interfaceType, String typeName)
		throws SqlXmlException
	{

		try {
			return types.getType(interfaceType, typeName);
		}
		catch (Exception e) {
			if (e instanceof SqlXmlException) {
				throw (SqlXmlException) e;
			}
			else {
				throw new SqlXmlException(e);
			}
		}
	}
	
	public Object newType(Class interfaceType, String typeName)
		throws SqlXmlException
	{
		try {
			return types.newType(interfaceType, typeName);
		}
		catch (Exception e) {
			if (e instanceof SqlXmlException) {
				throw (SqlXmlException) e;
			}
			else {
				throw new SqlXmlException(e);
			}
		}
	}
	
	/**
	 * Gets a script property.
	 */
	public Object getProperty(String key, Object defaultValue) {
		Object value = null;
		synchronized (this) {
			value = properties.get(key);
		}
		if (value == null) {
			value = defaultValue;
		}
		return value;
	}
	
	/**
	 * Gets a script property
	 * @param key
	 * @return
	 */
	public Object getProperty(String key) {
		synchronized (this) {
			return properties.get(key);
		}
	}
	
	/**
	 * Returns a copy of all the properties in the script.
	 * A copy is returned for thread safety.
	 * 
	 * @return
	 */
	public Map getProperties() {
		synchronized (this) {
			return new HashMap(properties);
		}
	}
	
	/**
	 * Sets a script property.
	 * 
	 * @param key
	 * @param value
	 */
	public void setProperty(String key, Object value) {
		properties.put(key, value);
	}
	
	/**
	 * Removes a property
	 * @param key
	 */
	public void clearProperty(String key) {
		properties.remove(key);
	}
	
	/**
	 * Removes a group of properties
	 * 
	 * Removing "row" would remove
	 *   row.EFF_DT
	 *   row.LAST_DT
	 *   row.person.age
	 * but not
	 *   rowashore.DATE
	 * 
	 * A dot is appended to the value passed in when searching for properties
	 * to remove.
	 * 
	 * @param parentKey
	 */
	public void clearProperties(String parentKey) {
		synchronized (this) {
			String _key = parentKey + ".";
			for (Iterator i = properties.entrySet().iterator(); i.hasNext();) {
				Map.Entry entry = (Map.Entry) i.next();
				String key = (String) entry.getKey();
				if (key.startsWith(_key)) {
					i.remove();
				}
			}
		}
	}
	
	/**
	 * Loads environment variables into the script properties
	 * prefixed with "env.".
	 *
	 */
	public void loadEnvironment() {
		Properties env = null;
		Map.Entry entry;
		clearProperties("env");
		env = Environment.getInstance().getEnvironment();
		if (env != null) {
			for (Iterator i=env.entrySet().iterator(); i.hasNext();) {
				entry = (Map.Entry) i.next();
				setProperty("env." + entry.getKey(), entry.getValue());
			}
		}
	}
	
	/**
	 * Sets the error property for the script
	 * @param t
	 */
	public void setError(Throwable t) {
		setProperty("error", t);
		//logger.error("setError: setting to " + t.getMessage(), t);
		if (t != null) {
			setProperty("stackTrace", ExceptionUtil.getStackTrace(t));
		}
		else {
			setProperty("stackTrace", null);
		}
	}
	
	/**
	 * Gets the error property for the script
	 * 
	 * @return
	 */
	public Throwable getError() {
		return (Throwable) getProperty("error");
	}
	
	/**
	 * Close all connections in a Map
	 * @param map
	 * @throws SQLException
	 */
	private void closeAll(Map map) {
		Connection c;
		String url;

		for (Iterator j=map.values().iterator(); j.hasNext();) {
			c = (Connection) j.next();
			try {
				url = c.getMetaData().getURL();
			}
			catch (Exception e) {
				url = c.toString();
			}
			logger.info("closeAll: closing " + url);
			try {
				c.close();
			}
			catch (SQLException sqle) {
				logger.error("closeAll: " + sqle.getMessage(), sqle);
			}
		}
	}
	
	/**
	 * Closes all connections.
	 * 
	 * @throws SQLException
	 */
	public void closeAll() {
		logger.info("closeAll: closing all connections");
		synchronized (this) {
			for (Iterator i=connections.values().iterator(); i.hasNext();) {
				closeAll((Map) i.next());
			}
			connections.clear();
		}
	}
	
	/**
	 * Rolls back all connections.
	 * @throws SQLException
	 */
	public void rollbackAll() throws SQLException {
		Map map;
		Connection c;
		String url;
		SQLException error = null;
		
		logger.info("rollbackAll: rolling back all non-autocommit connections");
		
		synchronized (this) {
			for (Iterator i=connections.values().iterator(); i.hasNext();) {
				map = (Map) i.next();
				for (Iterator j=map.values().iterator(); j.hasNext();) {
					c = (Connection) j.next();
					try {
						url = c.getMetaData().getURL();
					}
					catch (Exception e) {
						url = c.toString();
					}
					if (!c.getAutoCommit()) {
						logger.info("rollbackAll: rolling back " + url);
						try {
							c.rollback();
						}
						catch (SQLException sqle) {
							error = sqle;
							logger.error("rollbackAll: error rolling back " + url);
						}
					}
				}
			}
			if (error != null) {
				throw error;
			}
		}
	}
	
	/**
	 * Commits all connections.
	 * 
	 * @throws SQLException
	 */
	public void commitAll(boolean rollbackRemaining) throws SQLException {
		Map map;
		Connection c;
		String url;
		SQLException error = null;
		
		logger.info("commitAll: committing all non-autocommit connections");
		
		synchronized (this) {
			for (Iterator i=connections.values().iterator(); i.hasNext();) {
				map = (Map) i.next();
				for (Iterator j=map.values().iterator(); j.hasNext();) {
					c = (Connection) j.next();
					try {
						url = c.getMetaData().getURL();
					}
					catch (Exception e) {
						url = c.toString();
					}
					if (!c.getAutoCommit()) {
						if (!rollbackRemaining || (error == null)) {
							logger.info("commitAll: commiting " + url);
							try {
								c.commit();
							}
							catch (SQLException sqle) {
								error = sqle;
								logger.error("commitAll: error committing - " + sqle.getMessage(), sqle);
							}
						}
						else {
							logger.warn("commitAll: rolling back " + url);
							try {
								c.rollback();
							}
							catch (SQLException sqle) {
								logger.error("commitAll: " + sqle.getMessage(), sqle);
							}
						}
					}
				}
			}
			if (error != null) {
				throw error;
			}
		}
	}
	
	/**
	 * Clear resources allocated for a thread.
	 * @param t
	 */
	public void clearThreadResources(Thread t) {
		closeCachedThreadConnections(t);
	}
	
	/**
	 * Close all connections for a Thread
	 * @param t
	 */
	private void closeCachedThreadConnections(Thread t) {
		synchronized (this) {
			Map map = (Map) connections.get(t);
			if (map != null) {
				closeAll(map);
				connections.remove(t);
			}
		}
	}
	
	/**
	 * Gets a connection.
	 * 
	 * @param dsid
	 * @return
	 * @throws SqlXmlException
	 */
	public Connection getConnection(String dsid)
		throws SqlXmlException, SQLException
	{
		Thread t;
		Map map;
		Connection c;
		String url;
		boolean autoCommit;
		
		t = Thread.currentThread();
		logger.debug("getConnection - entering synchronized.....");
		synchronized (this) {
			logger.debug("getConnection - connections.get");
			map = (Map) connections.get(t);
			if (map == null) {
				logger.debug("getConnection - getNewConnection");
				map = new HashMap();
				connections.put(t, map);
			}
		}
		
		// Don't have to synchonize on inner Map
		// since the outer map is indexed by the Thread.
		c = (Connection) map.get(dsid);
		if (c == null) {
			logger.debug("getConnection - getNewConnection(dsid)");
			c = getNewConnection(dsid);
			map.put(dsid, c);
		}

		logger.debug("getConnection - exited synchronized.....");
		
		url = c.toString();
		try {
			url = c.getMetaData().getURL();
		}
		catch (SQLException sqle) {
		}

		autoCommit = c.getAutoCommit();
		logger.debug("getConnection: [" + url + "] autoCommit=[" + autoCommit +
			"] setting autoCommit to [" + this.autoCommit + "]");
		c.setAutoCommit(this.autoCommit);
		return c;
	}
	
	/*
	 * Closes a connection
	 */
	public void closeConnection(Connection c) {
		// do nothing connections will be closed at the end
//		if (c != null) {
//			try {
//				c.close();
//			}
//			catch (SQLException sqle) {
//				logger.error("closeConnection: " + sqle.getMessage(), sqle);
//			}
//		}
	}
	
	/**
	 * Adds a command to the execution stack.
	 * @param command
	 */
	public void addCommand(ICommand command) {
		synchronized (this) {
			commands.add(command);
		}
	}

	/**
	 * Expands properties in the text string, using Velocity.
	 * 
	 * @param text
	 * @return
	 * @throws SqlXmlException
	 */
	public String expandProperties(String text) throws SqlXmlException {
		try {
			Map props = getProperties();
			props.put("script", this);
			return TemplateUtil.evaluateTemplate(text, props);
		}
		catch (Exception e) {
			throw new SqlXmlException(e.getMessage(), e);
		}
	}
	
	/**
	 * Takes a Properties object and expands variables for all of its values.
	 * 
	 * @param props
	 * @throws SqlXmlException
	 */
	public void expandProperties(Properties props) throws SqlXmlException {
		Map copy = new HashMap();
		Map variables = getProperties();
		variables.put("script", this);
		for (Iterator i = props.entrySet().iterator(); i.hasNext();) {
			Map.Entry entry = (Map.Entry) i.next();
			try {
				copy.put(entry.getKey(),
					TemplateUtil.evaluateTemplate((String) entry.getValue(), variables));
			}
			catch (Exception e) {
				throw new SqlXmlException(e.getMessage(), e);
			}
		}
		props.putAll(copy);
	}
	
	/**
	 * uns an SQL statement
	 * @param c
	 * @param sql
	 * @param parseStatement
	 * @param timeout
	 * @throws SQLException
	 * @throws SqlXmlException
	 */
	public void runStatement(Connection c, String sql, boolean parseStatement,
		int timeout) throws SQLException, SqlXmlException
	{
		runStatement(c, sql, parseStatement, null, timeout);
	}
	
	/**
	 * Runs an SQL statement
	 * @param c
	 * @param sql
	 * @param parseStatement
	 * @throws SQLException
	 * @throws SqlXmlException
	 */
	public void runStatement(Connection c, String sql,
			boolean parseStatement)
		throws SQLException, SqlXmlException
	{
		runStatement(c, sql, parseStatement, null, 0);
	}
	
	/**
	 * Runs an SQL statement
	 * @param dsid
	 * @param sql
	 * @param parseStatement
	 * @param rowName
	 * @throws SQLException
	 * @throws SqlXmlException
	 */
	public void runStatement(Connection c, String sql,
			boolean parseStatement, String rowName)
		throws SQLException, SqlXmlException
	{
		runStatement(c, sql, parseStatement, rowName, 0);
		
	}
	
	/**
	 * Runs an SQL statement
	 * @param c
	 * @param sql
	 * @param parseStatement
	 * @param rowName
	 * @param timeout
	 * @throws SQLException
	 * @throws SqlXmlException
	 */
	public void runStatement(Connection c, String sql,
			boolean parseStatement, String rowName, int timeout)
		throws SQLException, SqlXmlException
	{	
		PreparedStatement ps = null;
		ResultSet rs = null;
		ResultSetMetaData rsmd = null;
		int count = 0;
		String type = "";
		String [] columnNames = null;
		Object [] lastRow = null;
		int ncols = 0;
		
		if ((rowName == null) || (rowName.equals(""))) {
			rowName = "row";
		}
		
		try {
			
			ps = prepare(c, sql, parseStatement);
			if (timeout > 0) {
				logger.info("runStatement: setting query timeout " + timeout);
				ps.setQueryTimeout(timeout);
			}
			ps.execute();
			while (true) {
				
				rs = ps.getResultSet();
				
				if (rs == null) {
					count = ps.getUpdateCount();
					type = "update";
				}
				else {
					type = "select";
					
					// Get the meta data
					rsmd = rs.getMetaData();
					ncols = rsmd.getColumnCount();
					columnNames = new String[ncols];
					lastRow = new Object[ncols];
					for (int i=0; i<ncols; i++) {
						columnNames[i] = rsmd.getColumnLabel(i+1);
					}
					
					// fetch rows
					while (rs.next()) {
						for (int i=0; i<ncols; i++) {
							lastRow[i] = rs.getObject(i+1);
						}
						count++;
					}

					// set properties for last row or null if there weren't any
					clearProperties(rowName);
					for (int i=0; i<ncols; i++) {
						setProperty(rowName + "." + (i+1), lastRow[i]);
						setProperty(rowName + "." + columnNames[i], lastRow[i]);
					}
				}
	
				clearProperties("error");
				setProperty("count", new Integer(count));
				setProperty("type", type);
				
				// any more results?
				if (!ps.getMoreResults() && (ps.getUpdateCount() == -1)) {
					break;
				}
				else {
					logger.info("runStatement: more than 1 result set.");
				}
			}
		}
		finally {
			if (ps != null) {
				ps.close();
			}
			if (rs != null) {
				rs.close();
			}
		}
	}
	
	/**
	 * Prepares a statement.  The statement is passed through a few phases.
	 * In the first phase it is run through velocity using the scripts properties.
	 * This allows you to create variables for things like table names and
	 * schemas.
	 * 
	 * In the 2nd phase the sql is prepared as a PreparedStatement or a 
	 * CallableStatement.
	 * 
	 * If the parseStatement parameter is set to true it is also parsed for 
	 * named placesholders.  A placeholder is a ?, you can name them like so
	 * ?{name}.  The names for the place holders are pulled from the scripts 
	 * properties.  This is different from the first phase in that the values
	 * are set on the prepared statement not directly replaced in the SQL.
	 * 
	 * @param c
	 * @param sql
	 * @param parseStatement
	 * @return
	 * @throws SqlXmlException
	 */
	public PreparedStatement prepare(Connection c, String sql,
		boolean parseStatement)
		throws SqlXmlException, SQLException
	{
		PreparedStatement ps = null;
		String _sql = null;
		try {
			String paramName = null;
			if (parseStatement) {
				ParsedStatement parsed = new ParsedStatement(sql, c);
				Iterator iterator = parsed.getParameterNames().iterator();
				while (iterator.hasNext()) {
					paramName = (String) iterator.next();
					parsed.setObject(paramName, getProperty(paramName));
				}
				ps = parsed.getPreparedStatement();
				_sql = parsed.getSqlStatement();
			}
			else {
				ps = ParsedStatement.prepare(c, sql);
				_sql = sql;
			}
			setLastStatement(_sql);
			return ps;
		}
		catch (DBException e) {
			throw new SqlXmlException(e);
		}
	}

	/**
	 * Parses the xml element to configure the script.
	 * @param element
	 * @throws SqlXmlException
	 */
	public void parse(Element element) throws SqlXmlException {
		try {
			// Load directives
			// properties, timestamps, datasources, types
			parseDirectives(element);	
			
			// Load the commands
			parseCommands(element);
		}
		catch (Exception e) {
			if (e instanceof SqlXmlException) {
				throw (SqlXmlException) e;
			}
			throw new SqlXmlException(e);
		}
	}
	
	/**
	 * Creates this script from an XML document.
	 * 
	 * @param resource
	 * @throws SqlXmlException
	 */
	public void parse(String resource) throws SqlXmlException {
		Element element = loadXML(resource);
		try {
			setProperty("scriptName", ResourceUtil.getResourceURL(resource).toExternalForm());
			parse(element);
		}
		catch (Exception e) {
			if (e instanceof SqlXmlException) {
				throw (SqlXmlException) e;
			}
			throw new SqlXmlException(e);
		}
	}

	/**
	 * Checks the properties to see if it has the attribute interpretProperties
	 * set to true.  If it does variable expansion is done on the properties.
	 * @param properties
	 * @throws SqlXmlException
	 */
	public void expandElementProperties(Properties properties)
		throws SqlXmlException
	{
		String interpretProperties = properties.getProperty("interpretProperties");
		// default is to expand the properties
		if (StringUtil.isEmpty(interpretProperties) ||
			Boolean.valueOf(interpretProperties).booleanValue())
		{
			expandProperties(properties);
		}
	}
	
	
	/**
	 * @param interfaceType
	 * @param node
	 * @return
	 * @throws Exception
	 */
	public ISqlXmlObject parse(Class interfaceType, Element node)
		throws Exception
	{
		String type;
		// Get the type
		type = node.getAttribute("type");
		if (StringUtil.isEmpty(type)) {
			throw new SAXException("The " + node.getNodeName() +
				" element should have a type attribute - " +
				XMLUtil.toString(node));
		}
		return parse(interfaceType, type, node);
	}
	

	/**
	 * @param interfaceType
	 * @param type
	 * @param node
	 * @return
	 * @throws Exception
	 */
	public ISqlXmlObject parse(Class interfaceType, String type, Element node)
		throws Exception
	{
		ISqlXmlObject object;
		
		object = (ISqlXmlObject) types.newType(interfaceType, type);
		object.onLoad(this);
		
		if (object instanceof IXMLInitializable) {
			((IXMLInitializable) object).initialize(node);
		}
		else {
			applyElementProperties(object, node);
		}
		
		return object;
	}
	
	/**
	 * Takes properties from an Element and applies them to an object.
	 * 
	 * @param object
	 * @param node
	 * @throws Exception
	 */
	public Properties applyElementProperties(Object object, Element node)
		throws Exception
	{
		Properties properties;
		properties = new Properties();
		XMLUtil.fillAttributeProperties(node, properties);
		applyElementProperties(object, properties);
		return properties;
	}
	
	/**
	 * Applies properties to an object from an element.
	 * 
	 * @param object
	 * @param properties
	 * @throws Exception
	 */
	public void applyElementProperties(Object object, Properties properties)
		throws Exception
	{
		expandElementProperties(properties);
		InitializeUtil.initialize(object, properties);
	}
	
	/**
	 * Executes the script.
	 * 
	 * @throws SqlXmlException
	 */
	public void execute() throws SqlXmlException, SQLException {
		ICommand command = null;
		
		setProperty("startTime", new Date());
		
		Iterator stack = commands.iterator();
		try {
			while (stack.hasNext()) {
				command = (ICommand) stack.next();
				logger.debug("execute: executing command " + command);
				command.execute(this);
			}
		}
		catch (SQLException sqle) {
			SQLException original = sqle;
			while (sqle != null) {
				logger.error("execute: [" + sqle.getErrorCode() + ":" +
					sqle.getSQLState() + "] " + sqle.getMessage(), sqle);
				sqle = sqle.getNextException();
			}
			throw original;
		}
	}
	
	/**
	 * Clean up script resources
	 * 
	 * @see com.caremark.gdx.common.IDisposable#dispose()
	 */
	public void dispose() {
		synchronized (this) {
			// dispose commands
			for (Iterator i = commands.iterator(); i.hasNext();) {
				Object cmd = i.next();
				if (cmd instanceof IDisposable) {
					try {
						((IDisposable) cmd).dispose();
					}
					catch (Exception e) {
						logger.error("dispose: " + e.getMessage(), e);
					}
				}
			}
			commands.clear();
			closeAll();
		}
	}
	
	/**
	 * String representation of script object.
	 * @return
	 * @see java.lang.Object#toString()
	 */
	public String toString() {
		StringBuffer sb = new StringBuffer();
		sb.append(super.toString());
		sb.append("\n");
		sb.append("  Properties:\n");
		synchronized (this) {
			for (Iterator i = properties.entrySet().iterator(); i.hasNext();) {
				Map.Entry entry = (Map.Entry) i.next();
				String value = (entry.getValue() == null) ? "" : entry.getValue().toString();
				sb.append("    ")
					.append(entry.getKey())
					.append(" = [")
					.append(StringEscapeUtils.escapeJava(value))
					.append("]\n");
			}
			sb.append("  Commands:\n");
			for (Iterator i = commands.iterator(); i.hasNext();) {
				sb.append("    ").append(i.next()).append("\n");
			}
		}
		return sb.toString();
	}
	


	/**
	 * @return Returns the autoCommit.
	 */
	public boolean isAutoCommit() {
		return autoCommit;
	}
	/**
	 * @param autoCommit The autoCommit to set.
	 */
	public void setAutoCommit(boolean autoCommit) {
		this.autoCommit = autoCommit;
	}

	
	/* PRIVATE METHODS ------------------------------------------------------ */
	
	private Connection getNewConnection(String dsid)
		throws SQLException, SqlXmlException
	{
		try {
			DataSource ds = getDataSourceRegistry().getDataSource(dsid);		
			logger.debug("getNewConnection: dsid=" + dsid);
			Connection c = ds.getConnection();
			logger.debug("getNewConnection: c=" + c);
			return c;
		}
		catch (DBException dbe) {
			if (dbe.getCause() != null) {
				throw new SqlXmlException(dbe.getCause());
			}
			else {
				throw new SqlXmlException(dbe);
			}
		}
	}
	
	/**
	 * Parse and run all directives.
	 * Directives are run immediately when they are encountered.
	 * Properties are created first, then directives, then datasources
	 * and finally commands.
	 * @param element
	 * @throws Exception
	 */
	private void parseDirectives(Element element) throws Exception
	{
		Node node;
		IDirective directive;
		
		// Non directive elements
		HashSet elements = new HashSet();
		//elements.add("datasource");
		//elements.add("datasources");
		elements.add("command");
		
		// Get all command nodes
		NodeList nodes = element.getChildNodes();
		for (int i=0; i<nodes.getLength(); i++) {
			node = nodes.item(i);
			if ((node instanceof Element) &&
				(!elements.contains(node.getNodeName())))
			{
				directive = (IDirective) parse(IDirective.class, node.getNodeName(), (Element) node);
				directive.execute(this);
			}
		}
	}
	
	/**
	 * Parse all of the commands
	 * @param element
	 * @throws Exception
	 */
	private void parseCommands(Element element) throws Exception
	{
		// Get all command nodes
		Element[] nodes = XMLUtil.getElementsByTagName(element, "command");
		for (int i=0; i<nodes.length; i++) {
			commands.add(parse(ICommand.class, nodes[i]));
		}
	}

	/**
	 * Utility method for loading an XML document.
	 * @param resource
	 * @return
	 * @throws SqlXmlException
	 */
	private static Element loadXML(String resource) throws SqlXmlException {
		InputStream input = null;
		try {
			// Parse into a dom object
			input = ResourceUtil.getInputStream(resource);
			return DocumentBuilderFactory
				.newInstance()
				.newDocumentBuilder()
				.parse(input)
				.getDocumentElement();
		}
		catch (Exception e) {
			throw new SqlXmlException("Couldn't load XML resource " + resource + " - " + e.getMessage(), e);
		}
		finally {
			if (input != null) {
				try {
					input.close();
				}
				catch (IOException ioe) {
				}
			}
		}
	}
	
	/* MAIN ----------------------------------------------------------------- */
	

	
	/**
	 * Print the usage
	 *
	 */
	private static void usage() {
		System.err.println("java " + SqlXmlScript.class.getName() + " [options] <file>");
	}
	
	/**
	 * Utility method allowing a script to override log4j settings.
	 * @param element
	 */
	private static void loadLog4j(Element element) {
		InputStream input = null;
		
		String logFile = element.getAttribute("logFile");
		if (StringUtil.isEmpty(logFile)) {
			logFile = "sqml.log";
		}
		
		String[] possibleConfigs = new String[] {
			element.getAttribute("logConfig"),
			System.getProperty("log4j.configuration"),
			"sqml.log4j.properties",
			"log4j.properties",
		};
		
		for (int i=0; i<possibleConfigs.length; i++) {
			try {
				input = getFilteredStream(possibleConfigs[i], logFile);
				if (input != null) {
					if (possibleConfigs[i].endsWith(".xml")) {
						Element logdoc = DocumentBuilderFactory
							.newInstance()
							.newDocumentBuilder()
							.parse(input)
							.getDocumentElement();
						DOMConfigurator.configure(logdoc);
					}
					else {
						Properties p = new Properties();
						p.load(input);
						PropertyConfigurator.configure(p);
					}
					break;
				}
			}
			catch (Exception e) {
			}
			finally {
				if (input != null) {
					try {
						input.close();
					}
					catch (Exception e) {
					}
					input = null;
				}
			}
		}
		
		// Get the logger one more time
		logger = org.apache.log4j.Logger.getLogger(SqlXmlScript.class.getName());
	}
	
	/**
	 * Load a resource and replace the token ${logFile} with logFile.
	 * 
	 * @param resource
	 * @param logFile
	 * @return
	 */
	private static InputStream getFilteredStream(String resource, String logFile)
	{
		String contents;
		InputStream input = null;
		
		try {
			contents = ResourceUtil.getResourceContents(resource);
			contents = StringUtil.replaceAll(contents, "\\$\\{logFile\\}", logFile);
			input = new ByteArrayInputStream(contents.getBytes());
		}
		catch (IOException ioe) {
		}
		
		return input;
	}
	
	/**
	 * Runs a script
	 * @param args
	 */
	public static void main(String [] args) {
		int exit_code = 0;
		SqlXmlScript script = null;
		String key;
		String val;
		boolean no_exit = false;
		boolean validate = false;
		String scriptName = null;
		long start_t = System.currentTimeMillis();
		Element scriptXml;
		
		try {
			script = new SqlXmlScript();
			
			// Parse arguments
			for (int i=0; i<args.length; i++) {
				if (args[i].equals("--no_exit")) {
					no_exit = true;
				}
				else if (args[i].equals("--validate")) {
					validate = true;
				}
				else if (args[i].startsWith("--")) {
					if (i<(args.length-1)) {
						key = args[i].substring(2);
						val = args[i+1];
						script.setProperty(key, val);
						i++;
					}
				}
				else {
					scriptName = args[i];
					break;
				}
			}
			
			if (scriptName == null) {
				usage();
				exit_code = 1;
			}
			else {
				scriptXml = loadXML(scriptName);
				loadLog4j(scriptXml);
				
				script.setProperty("scriptName", ResourceUtil.getResourceURL(scriptName).toExternalForm());
				script.loadEnvironment();
				script.parse(scriptXml);

				if (validate) {
					System.err.println(script);
				}
				else {
					script.execute();
				}
			}
			exit_code = 0;
		}
		catch (Exception e) {
			e.printStackTrace();
			exit_code = 1;
		}
		finally {
			if (script != null) {
				script.dispose();
			}
		}
		
		double execTime = (double) (System.currentTimeMillis() - start_t) / 1000.0;
		logger.warn("main: execution time " + execTime + " seconds.");
		logger.warn("main: exit code = " + exit_code);

		if (!no_exit) {
			System.exit(exit_code);
		}
	}
	/**
	 * @return Returns the lastStatement.
	 */
	public String getLastStatement() {
		return lastStatement;
	}
	/**
	 * @param lastStatement The lastStatement to set.
	 */
	public void setLastStatement(String lastAttemptedStatement) {
		this.lastStatement = lastAttemptedStatement;
	}
}
