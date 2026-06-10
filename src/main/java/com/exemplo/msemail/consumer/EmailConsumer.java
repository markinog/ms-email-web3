package com.exemplo.msemail.consumer;

import com.exemplo.msemail.dto.EmailRecordDto;
import com.exemplo.msemail.service.EmailService;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

@Component
public class EmailConsumer {

    private final EmailService emailService;

    public EmailConsumer(EmailService emailService) {
        this.emailService = emailService;
    }

    @RabbitListener(queues = "${broker.queue.email.name}")
    public void listenEmailQueue(EmailRecordDto emailRecordDto) {
        emailService.sendEmail(emailRecordDto);
    }
}
