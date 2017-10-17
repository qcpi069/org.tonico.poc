package com.caremark.gdx.sqml;

import java.sql.SQLException;

import com.caremark.gdx.common.mail.MailMessage;

/**
 * @author Bryan Castillo
 *
 */
public class CommandMail extends AbstractXMLCommand {
	
	private final static org.apache.log4j.Logger logger = org.apache.log4j.Logger
			.getLogger(CommandMail.class.getName());
	
	private String mailTo;
	private String mailFrom;
	private String subject;
	private String contentType = "text/plain";
	private boolean throwsException = true;
	
	/**
	 * @param script
	 * @throws SqlXmlException
	 * @throws SQLException
	 * @see com.caremark.gdx.sqml.ICommand#execute(com.caremark.gdx.sqml.SqlXmlScript)
	 */
	public void execute(SqlXmlScript script) throws SqlXmlException,
			SQLException
	{
		String _mailTo;
		String _mailFrom;
		String _subject;
		String _content;
		
		try {
			_mailTo = getScript().expandProperties(mailTo);
			_mailFrom = getScript().expandProperties(mailFrom);
			_subject = getScript().expandProperties(subject);
			_content = getScript().expandProperties(getContent());

			MailMessage message = new MailMessage();
			message.setFrom(_mailFrom);
			message.addTo(_mailTo);
			message.setSubject(_subject);
			message.setContentType(contentType);
			message.setContent(_content);
			message.send();
		}
		catch (Exception e) {
			if (!throwsException) {
				logger.error("execute: exception ignored while sending email.", e);
			}
			else {
				if (e instanceof SQLException) {
					throw (SQLException) e;
				}
				else if (e instanceof SqlXmlException) {
					throw (SqlXmlException) e;
				}
				else {
					throw new SqlXmlException(e);
				}
			}
		}
	}

	/**
	 * @return Returns the mailFrom.
	 */
	public String getMailFrom() {
		return mailFrom;
	}
	/**
	 * @param mailFrom The mailFrom to set.
	 */
	public void setMailFrom(String mailFrom) {
		this.mailFrom = mailFrom;
	}
	/**
	 * @return Returns the mailTo.
	 */
	public String getMailTo() {
		return mailTo;
	}
	/**
	 * @param mailTo The mailTo to set.
	 */
	public void setMailTo(String mailTo) {
		this.mailTo = mailTo;
	}
	/**
	 * @return Returns the subject.
	 */
	public String getSubject() {
		return subject;
	}
	/**
	 * @param subject The subject to set.
	 */
	public void setSubject(String subject) {
		this.subject = subject;
	}
	/**
	 * @return Returns the throwsException.
	 */
	public boolean isThrowsException() {
		return throwsException;
	}
	/**
	 * @param throwsException The throwsException to set.
	 */
	public void setThrowsException(boolean throwsException) {
		this.throwsException = throwsException;
	}
	/**
	 * @return Returns the contentType.
	 */
	public String getContentType() {
		return contentType;
	}
	/**
	 * @param contentType The contentType to set.
	 */
	public void setContentType(String contentType) {
		this.contentType = contentType;
	}
}
