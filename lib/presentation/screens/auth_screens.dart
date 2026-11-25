// Splash, boas-vindas, login e cadastro.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatters.dart';
import '../../core/scope.dart';
import '../../core/theme.dart';
import '../../domain/entities.dart';
import '../../domain/fila_rules.dart';
import '../widgets/common.dart';
import 'perf_lab_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: AppColors.primaria,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Logo(tamanho: 30),
              SizedBox(height: 28),
              SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
            ],
          ),
        ),
      );
}

class BoasVindasScreen extends StatelessWidget {
  const BoasVindasScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.primaria,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Logo(tamanho: 24),
                const Spacer(),
                const Text(
                  'Sua vez na fila,\nsem ficar na recepção.',
                  style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, height: 1.2),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Retire a senha pelo celular, acompanhe sua posição e seja avisado quando for chamado.',
                  style: TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
                ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primaria),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LoginPacienteScreen())),
                  child: const Text('Sou paciente'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                  ),
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LoginProfissionalScreen())),
                  child: const Text('Sou profissional de saúde'),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.white70, minimumSize: const Size(0, 44)),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PerfLabScreen())),
                    icon: const Icon(Icons.speed, size: 18),
                    label: const Text('Laboratório de performance'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------

class LoginPacienteScreen extends StatefulWidget {
  const LoginPacienteScreen({super.key});

  @override
  State<LoginPacienteScreen> createState() => _LoginPacienteScreenState();
}

class _LoginPacienteScreenState extends State<LoginPacienteScreen> {
  final _doc = TextEditingController();
  final _codigo = TextEditingController();
  bool _codigoEnviado = false;
  int _tentativas = 0;
  String? _erro;

  @override
  void dispose() {
    _doc.dispose();
    _codigo.dispose();
    super.dispose();
  }

  void _enviarCodigo() {
    final doc = _doc.text;
    if (!FilaRules.documentoValido(doc)) {
      setState(() => _erro = 'Digite um CPF válido (11 dígitos) ou o número do Cartão SUS (15 dígitos).');
      return;
    }
    final p = AppScope.of(context).repo.pacientePorDocumento(doc);
    if (p == null) {
      setState(() => _erro = null);
      _irParaCadastro();
      return;
    }
    setState(() {
      _codigoEnviado = true;
      _erro = null;
    });
    mostrarMensagem(context, 'Código enviado por SMS para ${p.telefone}. (Demonstração: digite qualquer código de 4 dígitos.)');
  }

  void _irParaCadastro() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => CadastroPacienteScreen(documento: _doc.text.replaceAll(RegExp(r'\D'), ''))),
    );
  }

  void _entrar() {
    // EX01: 5 tentativas erradas bloqueiam (aqui, qualquer código com 4 dígitos é aceito).
    if (_codigo.text.length != 4) {
      _tentativas++;
      setState(() => _erro = _tentativas >= 5
          ? 'Muitas tentativas. Login bloqueado por 30 minutos.'
          : 'Código inválido. Confira o SMS e tente de novo.');
      return;
    }
    final scope = AppScope.of(context);
    final p = scope.repo.pacientePorDocumento(_doc.text)!;
    Navigator.of(context).popUntil((r) => r.isFirst);
    scope.session.entrarPaciente(p);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Entrar como paciente')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Informe seu CPF ou Cartão SUS', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text('Vamos enviar um código por SMS para confirmar que é você.', style: TextStyle(color: AppColors.textoSecundario)),
            const SizedBox(height: 20),
            Campo(
              rotulo: 'CPF ou Cartão SUS',
              child: TextField(
                controller: _doc,
                enabled: !_codigoEnviado,
                keyboardType: TextInputType.number,
                inputFormatters: [DocumentoFormatter()],
                decoration: const InputDecoration(hintText: '000.000.000-00'),
                style: const TextStyle(fontSize: 18),
              ),
            ),
            if (_codigoEnviado) ...[
              const SizedBox(height: 16),
              Campo(
                rotulo: 'Código recebido por SMS',
                child: TextField(
                  controller: _codigo,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(hintText: '0000', counterText: ''),
                  style: const TextStyle(fontSize: 22, letterSpacing: 8),
                ),
              ),
            ],
            if (_erro != null) ...[
              const SizedBox(height: 14),
              Aviso.perigo(texto: _erro!),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _tentativas >= 5 ? null : (_codigoEnviado ? _entrar : _enviarCodigo),
              child: Text(_codigoEnviado ? 'Entrar' : 'Continuar'),
            ),
            const SizedBox(height: 10),
            if (!_codigoEnviado)
              OutlinedButton(onPressed: _irParaCadastro, child: const Text('Ainda não tenho cadastro'))
            else
              TextButton(
                onPressed: () => setState(() {
                  _codigoEnviado = false;
                  _codigo.clear();
                }),
                child: const Text('Usar outro documento'),
              ),
            const SizedBox(height: 24),
            const Aviso.info(
              titulo: 'Demonstração:',
              texto: 'a paciente Maria Silva já está cadastrada com o CPF 529.982.247-25.',
            ),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------

class CadastroPacienteScreen extends StatefulWidget {
  const CadastroPacienteScreen({super.key, this.documento = ''});
  final String documento;

  @override
  State<CadastroPacienteScreen> createState() => _CadastroPacienteScreenState();
}

class _CadastroPacienteScreenState extends State<CadastroPacienteScreen> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _nasc = TextEditingController();
  final _tel = TextEditingController();
  late final _doc = TextEditingController(
    text: DocumentoFormatter().formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: widget.documento)).text,
  );
  bool _aceite = false;

  @override
  void dispose() {
    _nome.dispose();
    _nasc.dispose();
    _tel.dispose();
    _doc.dispose();
    super.dispose();
  }

  DateTime? _data(String t) {
    final p = t.split('/');
    if (p.length != 3 || p[2].length != 4) return null;
    final d = DateTime.tryParse('${p[2]}-${p[1]}-${p[0]}');
    if (d == null || d.isAfter(DateTime.now()) || d.year < 1900) return null;
    return d;
  }

  void _salvar() {
    if (!_form.currentState!.validate()) return;
    if (!_aceite) {
      mostrarMensagem(context, 'É preciso aceitar o uso dos dados para continuar.', erro: true);
      return;
    }
    final scope = AppScope.of(context);
    // EX02: documento já cadastrado.
    if (scope.repo.pacientePorDocumento(_doc.text) != null) {
      mostrarMensagem(context, 'Este documento já tem cadastro. Volte e entre com ele.', erro: true);
      return;
    }
    final p = scope.repo.cadastrarPaciente(
      nome: _nome.text,
      nascimento: _data(_nasc.text)!,
      telefone: _tel.text,
      documento: _doc.text,
    );
    Navigator.of(context).popUntil((r) => r.isFirst);
    scope.session.entrarPaciente(p);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Criar cadastro')),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Campo(
                rotulo: 'Nome completo',
                child: TextFormField(
                  controller: _nome,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v ?? '').trim().split(' ').length < 2 ? 'Digite nome e sobrenome' : null,
                ),
              ),
              const SizedBox(height: 16),
              Campo(
                rotulo: 'Data de nascimento',
                child: TextFormField(
                  controller: _nasc,
                  keyboardType: TextInputType.number,
                  inputFormatters: [MascaraFormatter('##/##/####')],
                  decoration: const InputDecoration(hintText: 'dd/mm/aaaa'),
                  validator: (v) => _data(v ?? '') == null ? 'Data inválida' : null,
                ),
              ),
              const SizedBox(height: 16),
              Campo(
                rotulo: 'Celular',
                child: TextFormField(
                  controller: _tel,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [MascaraFormatter('(##) #####-####')],
                  decoration: const InputDecoration(hintText: '(86) 99999-9999'),
                  validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length < 11 ? 'Celular inválido' : null,
                ),
              ),
              const SizedBox(height: 16),
              Campo(
                rotulo: 'CPF ou Cartão SUS',
                child: TextFormField(
                  controller: _doc,
                  keyboardType: TextInputType.number,
                  inputFormatters: [DocumentoFormatter()],
                  validator: (v) => FilaRules.documentoValido(v ?? '') ? null : 'CPF ou Cartão SUS inválido',
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _aceite,
                onChanged: (v) => setState(() => _aceite = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Autorizo o uso dos meus dados para organizar o atendimento, conforme a LGPD.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _salvar, child: const Text('Criar cadastro e entrar')),
            ],
          ),
        ),
      );
}

// ---------------------------------------------------------------------------

class LoginProfissionalScreen extends StatefulWidget {
  const LoginProfissionalScreen({super.key});

  @override
  State<LoginProfissionalScreen> createState() => _LoginProfissionalScreenState();
}

class _LoginProfissionalScreenState extends State<LoginProfissionalScreen> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _ocultar = true;
  String? _erro;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  void _entrar() {
    final scope = AppScope.of(context);
    final f = scope.repo.autenticar(_email.text, _senha.text);
    if (f == null) {
      setState(() => _erro = 'E-mail ou senha incorretos, ou usuário desativado.');
      return;
    }
    Navigator.of(context).popUntil((r) => r.isFirst);
    scope.session.entrarFuncionario(f);
  }

  void _preencher(String email) {
    _email.text = email;
    _senha.text = '123456';
    setState(() => _erro = null);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Acesso da equipe')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Campo(
              rotulo: 'E-mail',
              child: TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
              ),
            ),
            const SizedBox(height: 16),
            Campo(
              rotulo: 'Senha',
              child: TextField(
                controller: _senha,
                obscureText: _ocultar,
                decoration: InputDecoration(
                  suffixIcon: IconButton(
                    tooltip: _ocultar ? 'Mostrar senha' : 'Ocultar senha',
                    icon: Icon(_ocultar ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _ocultar = !_ocultar),
                  ),
                ),
                onSubmitted: (_) => _entrar(),
              ),
            ),
            if (_erro != null) ...[
              const SizedBox(height: 14),
              Aviso.perigo(texto: _erro!),
            ],
            const SizedBox(height: 24),
            FilledButton(onPressed: _entrar, child: const Text('Entrar')),
            const SizedBox(height: 28),
            const SecaoTitulo('Contas de teste (senha 123456)'),
            for (final (email, perfil) in const [
              ('recepcao@filasaude.com', Perfil.recepcao),
              ('enfermeiro@filasaude.com', Perfil.enfermeiro),
              ('medico@filasaude.com', Perfil.medico),
              ('coordenador@filasaude.com', Perfil.coordenador),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  onTap: () => _preencher(email),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(perfil.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(email, style: const TextStyle(fontSize: 13, color: AppColors.textoSecundario)),
                          ],
                        ),
                      ),
                      const Icon(Icons.login, color: AppColors.primaria),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}
