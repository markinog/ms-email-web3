const path = require('path');
const express = require('express');
const axios = require('axios');

const app = express();

const PORT = process.env.PORT || 3000;
const USER_SERVICE_URL = process.env.USER_SERVICE_URL || 'http://localhost:8081';

app.use(express.urlencoded({ extended: true }));
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.post('/send-code', async (req, res) => {
    const email = req.body.email;
    try {
        await axios.post(`${USER_SERVICE_URL}/auth/request-code`, { email });
        res.redirect(`/verify?email=${encodeURIComponent(email)}`);
    } catch (err) {
        console.error('[send-code] falha ao chamar User Service:', err.response?.status, err.response?.data || err.code || err.message);
        const message = err.response?.data?.error || err.response?.data?.message || 'Nao foi possivel enviar o codigo. Tente novamente.';
        res.status(400).send(renderError('Erro ao solicitar codigo', message, '/'));
    }
});

app.get('/verify', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'verify.html'));
});

app.post('/verify-code', async (req, res) => {
    const { email, code } = req.body;
    try {
        const response = await axios.post(`${USER_SERVICE_URL}/auth/verify-code`, { email, code });
        const token = response.data?.token || response.data?.accessToken || response.data;
        res.json({ ok: true, token });
    } catch (err) {
        const message = err.response?.data?.error || err.response?.data?.message || 'Codigo invalido ou expirado.';
        res.status(400).json({ ok: false, message });
    }
});

function renderError(title, message, backUrl) {
    return `<!DOCTYPE html>
<html lang="pt-br">
<head><meta charset="utf-8"><title>${title}</title></head>
<body style="font-family: sans-serif; max-width: 480px; margin: 60px auto;">
  <h2>${title}</h2>
  <p style="color:#c0392b;">${message}</p>
  <a href="${backUrl}">Voltar</a>
</body>
</html>`;
}

app.listen(PORT, () => {
    console.log(`Frontend rodando em http://localhost:${PORT}`);
    console.log(`User Service esperado em ${USER_SERVICE_URL}`);
});
