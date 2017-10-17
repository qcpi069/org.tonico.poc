package com.caremark.gdx.sqml;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.sql.SQLException;
import java.util.Properties;

import org.apache.commons.net.ftp.FTPClient;

import com.caremark.gdx.common.util.StringUtil;


/**
 * @author Bryan Castillo
 *
 */
public class CommandFtp extends AbstractXMLCommand {
	
	private final static org.apache.log4j.Logger logger = org.apache.log4j.Logger
			.getLogger(CommandFtp.class.getName());
	
	private String action = "";
	private String localFile;
	private String remoteFile;
	
	private String host;
	private int port = 21;
	private String userName;
	private String password;
	private String workingDirectory;
	private String tempFileSuffix = ".tmp~";
	private String fileType = "ASCII";
	private int maxTries = 3;
	
	private int mode;
	
	/**
	 * @param script
	 * @throws SqlXmlException
	 * @throws SQLException
	 * @see com.caremark.gdx.sqml.ICommand#execute(com.caremark.gdx.sqml.SqlXmlScript)
	 */
	public void execute(SqlXmlScript script) throws SqlXmlException,
			SQLException
	{
		
		// Re-evaluate properties
		Properties props = new Properties();
		props.putAll(getProperties());
		try {
			script.applyElementProperties(this, props);
		}
		catch (Exception e) {
			throw new SqlXmlException(e);
		}
		
		// Check the action
		if (!"PUT".equalsIgnoreCase(action) &&
			!"GET".equalsIgnoreCase(action))
		{
			throw new SqlXmlException("The action attribute should be GET or PUT");
		}

		// check the file type
		if (fileType.equalsIgnoreCase("ASCII")) {
			mode = FTPClient.ASCII_FILE_TYPE;
		}
		else if (fileType.equalsIgnoreCase("BINARY")) {
			mode = FTPClient.BINARY_FILE_TYPE;
		}
		else {
			throw new SqlXmlException("Invalid attribute for fileType " + fileType);
		}
		
		if (maxTries < 1) {
			maxTries = 1;
		}
		
		int tries = 0;
		Exception lastError = null;
		while (tries < maxTries) {
			try {
				_execute(script);
				lastError = null;
				break;
			}
			catch (Exception e) {
				logger.error("execute: " + e.getMessage(), e);
				lastError = e;
			}
			tries++;
		}
		if (lastError != null) {
			if (lastError instanceof SqlXmlException) {
				throw (SqlXmlException) lastError;
			}
			else {
				throw new SqlXmlException(lastError);
			}
		}
	}

	private void putFile(FTPClient ftp) throws Exception {
		String _remotefile;
		String _tmpname;
		
		if (StringUtil.isEmpty(localFile)) {
			throw new SqlXmlException("No localFile attribute was specified for PUT operation.");
		}
		_remotefile = this.remoteFile;
		if (StringUtil.isEmpty(_remotefile)) {
			File file = new File(localFile);
			_remotefile = file.getName();
		}
		InputStream in = new FileInputStream(localFile);
		try {
			if (!StringUtil.isEmpty(tempFileSuffix)) {
				_tmpname = _remotefile + tempFileSuffix;
			}
			else {
				_tmpname = _remotefile;
			}
			logger.info("_execute: storing file " + _tmpname);
			if (!ftp.storeFile(_tmpname, in)) {
				throw new SqlXmlException(
					"Couldn't store file " + _tmpname + " - " + ftp.getReplyString());
			}
			in.close();
			in = null;
			if (!_tmpname.equals(_remotefile)) {
				ftp.deleteFile(_remotefile);
				logger.info("_execute: renaming file " + _tmpname + " to " + _remotefile);
				if (!ftp.rename(_tmpname, _remotefile)) {

					throw new SqlXmlException("Couldn't rename " + _tmpname +
						" to " + _remotefile + " - " + ftp.getReplyString());
				}
			}
		}
		finally {
			if (in != null) {
				try {
					in.close();
				}
				catch (IOException ioe) {
				}
				in = null;
			}
		}	
	}
	
	private void getFile(FTPClient ftp) throws Exception {
		String _localfile;
		String _tmpname;
		
		if (StringUtil.isEmpty(remoteFile)) {
			throw new SqlXmlException("No remoteFile attribute was specified for GET operation.");
		}
		_localfile = this.localFile;
		if (StringUtil.isEmpty(_localfile)) {
			File file = new File(remoteFile);
			_localfile = file.getName();
		}
		if (!StringUtil.isEmpty(tempFileSuffix)) {
			_tmpname = _localfile + tempFileSuffix;
		}
		else {
			_tmpname = _localfile;
		}
		OutputStream out = new FileOutputStream(_tmpname);
		try {
			logger.info("_execute: retrieving file " + remoteFile);
			if (!ftp.retrieveFile(remoteFile, out)) {
				throw new SqlXmlException(
					"Couldn't retrieve file " + remoteFile + " - " + ftp.getReplyString());
			}
			out.close();
			out = null;
			if (!_tmpname.equals(_localfile)) {
				File tmpFile = new File(_tmpname);
				File localFile = new File(_localfile);
				// Delete the target file name if it exists
				// otherwise renameTo fails.
				if (localFile.exists()) {
					localFile.delete();
				}
				if (!tmpFile.renameTo(localFile)) {
					throw new SqlXmlException("Couldn't rename " + _tmpname + " to " + _localfile);
				}
			}
		}
		finally {
			if (out != null) {
				try {
					out.close();
				}
				catch (IOException ioe) {
				}
				out = null;
			}
		}
	}
	
	private void _execute(SqlXmlScript script) throws Exception {
		FTPClient ftp = new FTPClient();
		
		try {
			logger.info("_execute: connecting to " + host + ":" + port);
			ftp.connect(host, port);
			logger.info("_execute: logging in as " + userName);
			if (!ftp.login(userName, password)) {
				throw new SqlXmlException("Couldn't login to " + host +
					":" + port + " for user " + userName +
					" - " + ftp.getReplyString());
			}
			
			if (workingDirectory != null) {
				logger.info("_execute: changing to directory " + workingDirectory);
				if (!ftp.changeWorkingDirectory(workingDirectory)) {
					throw new SqlXmlException(
						"Couldn't change to remote directory " +
						workingDirectory + " - " + ftp.getReplyString());
				}
			}
			
			if (!ftp.setFileType(mode)) {
				throw new SqlXmlException(
						"Couldn't set file type " + " - " + ftp.getReplyString());
			}
			
			// Perform action
			if (action.equalsIgnoreCase("GET")) {
				getFile(ftp);
			}
			else {
				putFile(ftp);
			}
		}
		finally {
			if (ftp != null) {
				try {
					ftp.disconnect();
				}
				catch (Exception e) {
					logger.error("_execute: " + e.getMessage(), e);
				}
				ftp = null;
			}
		}
	}
	
	
	/**
	 * @return Returns the action.
	 */
	public String getAction() {
		return action;
	}
	/**
	 * @param action The action to set.
	 */
	public void setAction(String action) {
		this.action = action;
	}
	/**
	 * @return Returns the fileType.
	 */
	public String getFileType() {
		return fileType;
	}
	/**
	 * @param fileType The fileType to set.
	 */
	public void setFileType(String fileType) {
		this.fileType = fileType;
	}
	/**
	 * @return Returns the host.
	 */
	public String getHost() {
		return host;
	}
	/**
	 * @param host The host to set.
	 */
	public void setHost(String host) {
		this.host = host;
	}
	/**
	 * @return Returns the localFile.
	 */
	public String getLocalFile() {
		return localFile;
	}
	/**
	 * @param localFile The localFile to set.
	 */
	public void setLocalFile(String localFile) {
		this.localFile = localFile;
	}
	/**
	 * @return Returns the maxTries.
	 */
	public int getMaxTries() {
		return maxTries;
	}
	/**
	 * @param maxTries The maxTries to set.
	 */
	public void setMaxTries(int maxTries) {
		this.maxTries = maxTries;
	}
	/**
	 * @return Returns the password.
	 */
	public String getPassword() {
		return password;
	}
	/**
	 * @param password The password to set.
	 */
	public void setPassword(String password) {
		this.password = password;
	}
	/**
	 * @return Returns the port.
	 */
	public int getPort() {
		return port;
	}
	/**
	 * @param port The port to set.
	 */
	public void setPort(int port) {
		this.port = port;
	}
	/**
	 * @return Returns the remoteFile.
	 */
	public String getRemoteFile() {
		return remoteFile;
	}
	/**
	 * @param remoteFile The remoteFile to set.
	 */
	public void setRemoteFile(String remoteFile) {
		this.remoteFile = remoteFile;
	}
	/**
	 * @return Returns the tempFileSuffix.
	 */
	public String getTempFileSuffix() {
		return tempFileSuffix;
	}
	/**
	 * @param tempFileSuffix The tempFileSuffix to set.
	 */
	public void setTempFileSuffix(String tempFileSuffix) {
		this.tempFileSuffix = tempFileSuffix;
	}
	/**
	 * @return Returns the userName.
	 */
	public String getUserName() {
		return userName;
	}
	/**
	 * @param userName The userName to set.
	 */
	public void setUserName(String userName) {
		this.userName = userName;
	}
	/**
	 * @return Returns the workingDirectory.
	 */
	public String getWorkingDirectory() {
		return workingDirectory;
	}
	/**
	 * @param workingDirectory The workingDirectory to set.
	 */
	public void setWorkingDirectory(String workingDirectory) {
		this.workingDirectory = workingDirectory;
	}
}
