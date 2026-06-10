package com.exemplo.msemail.service;

import com.exemplo.msemail.dto.EmailRecordDto;
import com.exemplo.msemail.enums.EmailStatus;
import com.exemplo.msemail.model.EmailModel;
import com.exemplo.msemail.repository.EmailRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;

@Service
public class EmailService {

    private final EmailRepository emailRepository;
    private final JavaMailSender emailSender;

    @Value("${spring.mail.username}")
    private String emailFrom;

    public EmailService(EmailRepository emailRepository, JavaMailSender emailSender) {
        this.emailRepository = emailRepository;
        this.emailSender = emailSender;
    }

    public EmailModel sendEmail(EmailRecordDto emailRecordDto) {
        EmailModel emailModel = new EmailModel();
        emailModel.setUserId(emailRecordDto.userId());
        emailModel.setEmailFrom(emailFrom);
        emailModel.setEmailTo(emailRecordDto.emailTo());
        emailModel.setSubject(emailRecordDto.subject());
        emailModel.setText(emailRecordDto.text());
        emailModel.setSendDateEmail(LocalDateTime.now());

        try {
            SimpleMailMessage message = new SimpleMailMessage();
            message.setFrom(emailFrom);
            message.setTo(emailRecordDto.emailTo());
            message.setSubject(emailRecordDto.subject());
            message.setText(emailRecordDto.text());
            emailSender.send(message);

            emailModel.setStatus(EmailStatus.SENT);
        } catch (Exception e) {
            emailModel.setStatus(EmailStatus.ERROR);
        }

        return emailRepository.save(emailModel);
    }
}
