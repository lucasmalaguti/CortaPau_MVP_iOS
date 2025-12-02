import "dotenv/config";
import Fastify from "fastify";
import cors from "@fastify/cors";
import { PrismaClient, Role, Status, Categoria } from "@prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";
import { z } from "zod";
import fs from "node:fs";
import path from "node:path";
import { randomUUID } from "node:crypto";

const app = Fastify({
  logger: true,
  // Aumenta o limite de tamanho do corpo da requisição para suportar imagens base64
  // 10 MB (ajuste se precisar de mais)
  bodyLimit: 10 * 1024 * 1024,
});

// Configuração Prisma + Postgres remoto usando o adapter oficial (@prisma/adapter-pg)
const connectionString = process.env.DATABASE_URL;
if (!connectionString) {
  throw new Error("DATABASE_URL não está definida. Verifique o arquivo .env");
}

const adapter = new PrismaPg({ connectionString });
const prisma = new PrismaClient({ adapter });

// CORS liberado para o app rodando no simulador
app.register(cors, {
  origin: true,
});

// --- Tipos de resposta da API (batendo com o app iOS) ---

type ApiAnexo = {
  id: string;
  url: string;
  mime: string;
};

type ApiUsuarioResumo = {
  id: string;
  nome: string;
  role: string;
};

type ApiSolicitacao = {
  id: string;
  titulo: string;
  descricao: string;
  categoria: string;
  status: string;
  latitude: number;
  longitude: number;
  createdAt: string; // ISO string
  autor: ApiUsuarioResumo;
  anexos: ApiAnexo[];
};

type ApiEvento = {
  id: string;
  tipo: string;
  descricao: string | null;
  antigoStatus: string | null;
  novoStatus: string | null;
  createdAt: string; // ISO string
  autor: ApiUsuarioResumo | null;
};

type ApiEventosResponse = {
  status: string;
  items: ApiEvento[];
};

// Usuário retornado pela API após login
type ApiUser = {
  id: string;
  nome: string;
  login: string;
  role: Role;
};

// Corpo esperado no POST /auth/login
const loginBodySchema = z.object({
  login: z.string().min(1),
  senha: z.string().min(1),
});

// Helper para mapear do modelo Prisma -> DTO da API
function toApiSolicitacao(
  s: any & {
    autor: { id: string; nome: string; role: Role };
    anexos?: { id: string; url: string; mime: string }[];
  }
): ApiSolicitacao {
  return {
    id: s.id,
    titulo: s.titulo,
    descricao: s.descricao,
    categoria: s.categoria, // "RISCO_ELETRICO", "RISCO_QUEDAS", etc.
    status: s.status, // "NOVA", "EM_ATENDIMENTO", ...
    latitude: s.latitude,
    longitude: s.longitude,
    createdAt: s.createdAt.toISOString(),
    autor: {
      id: s.autor.id,
      nome: s.autor.nome,
      role: s.autor.role,
    },
    anexos: (s.anexos ?? []).map((a: any) => ({
      id: a.id,
      url: a.url,
      mime: a.mime,
    })),
  };
}

function toApiEvento(
  e: any & {
    autor?: { id: string; nome: string; role: Role } | null;
  }
): ApiEvento {
  return {
    id: e.id,
    tipo: e.tipo,
    descricao: e.descricao ?? null,
    antigoStatus: e.antigoStatus ?? null,
    novoStatus: e.novoStatus ?? null,
    createdAt: e.createdAt.toISOString(),
    autor: e.autor
      ? {
          id: e.autor.id,
          nome: e.autor.nome,
          role: e.autor.role,
        }
      : null,
  };
}

// --- Schemas Zod ---

const createSolicitacaoBody = z.object({
  titulo: z.string().min(3),
  descricao: z.string().min(5),
  categoria: z.enum(["RISCO_ELETRICO", "RISCO_QUEDAS", "PODA_ROTINEIRA", "OUTROS"]),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  // Opcional: id do autor vindo do app (usuário autenticado).
  autorId: z.string().cuid().optional(),
  // Opcional: anexos já enviados (URLs) para esta solicitação.
  anexos: z
    .array(
      z.object({
        url: z.string().min(1),
        mime: z.string().min(1),
      })
    )
    .optional(),
});

const updateSolicitacaoBody = z.object({
  status: z
    .enum(["NOVA", "EM_ATENDIMENTO", "CONCLUIDA", "NAO_CONCLUIDA"])
    .optional(),
  descricao: z.string().min(1).optional(),

  // Campos específicos do atendimento (tela de operário)
  atendimentoDescricao: z.string().min(1).optional(),
  atendimentoEncaminhamento: z
    .enum(["DEFESA_CIVIL", "BOMBEIROS", "COMPANHIA_ENERGIA", "OUTROS"])
    .optional(),
  atendimentoStatus: z
    .enum(["ATENDIDO_SUCESSO", "NAO_ATENDIDO", "ENCAMINHADO"])
    .optional(),
  operadorId: z.string().cuid().optional(),
});

// Corpo esperado no upload base64 de imagem (MVP)
const uploadBase64Body = z.object({
  imagemBase64: z.string().min(1), // string base64 (sem prefixo data:)
  mime: z.string().min(1), // ex: "image/jpeg", "image/png"
});

// Upload simples de imagem em base64, salvando em disco local e retornando uma URL
app.post("/uploads/base64", async (request, reply) => {
  const body = uploadBase64Body.parse(request.body);

  try {
    const buffer = Buffer.from(body.imagemBase64, "base64");

    // Diretório local para armazenar uploads (relativo ao server.ts)
    const uploadsDir = path.join(__dirname, "..", "uploads");
    if (!fs.existsSync(uploadsDir)) {
      fs.mkdirSync(uploadsDir, { recursive: true });
    }

    const ext =
      body.mime === "image/png"
        ? ".png"
        : body.mime === "image/webp"
        ? ".webp"
        : ".jpg";

    const fileName = `${randomUUID()}${ext}`;
    const filePath = path.join(uploadsDir, fileName);

    fs.writeFileSync(filePath, buffer);

    const urlPath = `/uploads/${fileName}`;

    return reply.send({
      status: "ok",
      url: urlPath,
      mime: body.mime,
    });
  } catch (err) {
    request.log.error(err);
    return reply
      .status(500)
      .send({ status: "error", message: "Falha ao salvar imagem." });
  }
});

// Rota simples para servir arquivos de /uploads
app.get("/uploads/:fileName", async (request, reply) => {
  const params = request.params as { fileName: string };
  const uploadsDir = path.join(__dirname, "..", "uploads");
  const filePath = path.join(uploadsDir, params.fileName);

  if (!fs.existsSync(filePath)) {
    return reply.status(404).send({ status: "error", message: "Arquivo não encontrado." });
  }

  // Conteúdo: imagem genérica; idealmente poderíamos inferir pelo mime salvo no banco
  const stream = fs.createReadStream(filePath);
  reply.header("Content-Type", "application/octet-stream");
  return reply.send(stream);
});


// --- Rotas ---

app.get("/health", async () => {
  return { status: "ok" };
});

// Rota de debug para garantir que o usuário de teste exista no banco
app.post("/debug/create-teste-user", async (request, reply) => {
  const senha = "teste";

  // Usuário 1: login "teste"
  const userTeste = await prisma.usuario.upsert({
    where: { email: "teste" },
    update: { hash: senha },
    create: {
      nome: "Usuário teste",
      email: "teste", // usamos o campo email como login simples
      hash: senha,    // senha em texto puro para MVP
      role: Role.USER,
    },
  });

  // Usuário 2: login "lucas@teste.com"
  const userLucas = await prisma.usuario.upsert({
    where: { email: "lucas@teste.com" },
    update: { hash: senha },
    create: {
      nome: "Lucas (teste)",
      email: "lucas@teste.com",
      hash: senha,
      role: Role.USER,
    },
  });

  const users: ApiUser[] = [
    {
      id: userTeste.id,
      nome: userTeste.nome,
      login: userTeste.email,
      role: userTeste.role,
    },
    {
      id: userLucas.id,
      nome: userLucas.nome,
      login: userLucas.email,
      role: userLucas.role,
    },
  ];

  return { status: "ok", users };
});
// Rota de login simples (MVP)
app.post("/auth/login", async (request, reply) => {
  const body = loginBodySchema.parse(request.body);

  const user = await prisma.usuario.findUnique({
    where: { email: body.login },
  });

  if (!user || user.hash !== body.senha) {
    return reply
      .status(401)
      .send({ status: "error", message: "Credenciais inválidas" });
  }

  const apiUser: ApiUser = {
    id: user.id,
    nome: user.nome,
    login: user.email,
    role: user.role,
  };

  return { status: "ok", user: apiUser };
});

// Rota de registro de novo usuário (MVP simples)
app.post("/auth/register", async (request, reply) => {
  type RegisterBody = {
    nome?: string;
    email?: string;
    senha?: string;
  };

  const body = request.body as RegisterBody;

  if (!body?.nome || !body?.email || !body?.senha) {
    reply.status(400).send({
      status: "error",
      message: "Nome, e-mail e senha são obrigatórios.",
    });
    return;
  }

  try {
    // Verifica se o e-mail já está cadastrado
    const existing = await prisma.usuario.findUnique({
      where: { email: body.email },
    });

    if (existing) {
      reply.status(400).send({
        status: "error",
        message: "E-mail já cadastrado.",
      });
      return;
    }

    // Para o MVP, usamos a senha em texto puro no campo `hash`
    // (no futuro, vamos trocar por hash seguro com Argon2).
    const user = await prisma.usuario.create({
      data: {
        nome: body.nome,
        email: body.email,
        hash: body.senha,
        role: Role.USER,
      },
    });

    const apiUser: ApiUser = {
      id: user.id,
      nome: user.nome,
      login: user.email,
      role: user.role,
    };

    reply.send({
      status: "ok",
      user: apiUser,
    });
  } catch (err) {
    console.error("Erro em /auth/register:", err);
    reply.status(500).send({
      status: "error",
      message: "Erro ao registrar usuário.",
    });
  }
});

// Lista solicitações (já usada pelo app iOS)
app.get("/solicitacoes", async (): Promise<ApiSolicitacoesResponse> => {
  const solicitacoes = await prisma.solicitacao.findMany({
    orderBy: { createdAt: "desc" },
    include: { autor: true, anexos: true },
  });

  const items = solicitacoes.map(toApiSolicitacao);

  return {
    status: "ok",
    total: items.length,
    items,
  };
});

// Cria uma nova solicitação
app.post("/solicitacoes", async (request, reply) => {
  const body = createSolicitacaoBody.parse(request.body);
  request.log.info(
    { hasAnexos: !!body.anexos, anexosCount: body.anexos?.length ?? 0 },
    "POST /solicitacoes - corpo recebido"
  );

  // Se o app enviar um autorId (usuário autenticado), usamos ele.
  // Caso contrário, caímos no usuário "Cidadão Demo" temporário.
  let autorId = body.autorId;

  if (!autorId) {
    const autorDemo = await prisma.usuario.upsert({
      where: { email: "cidadao_demo@cortapau.local" },
      update: {},
      create: {
        nome: "Cidadão Demo",
        email: "cidadao_demo@cortapau.local",
        hash: "demo-hash", // placeholder
        role: Role.USER,
      },
    });
    autorId = autorDemo.id;
  }

  const solicitacao = await prisma.solicitacao.create({
    data: {
      titulo: body.titulo,
      descricao: body.descricao,
      categoria: body.categoria as Categoria,
      status: Status.NOVA,
      latitude: body.latitude,
      longitude: body.longitude,
      autorId: autorId,
      anexos: body.anexos
        ? {
            create: body.anexos.map((a) => ({
              url: a.url,
              mime: a.mime,
              tamanhoBytes: 0, // MVP: não calculamos o tamanho real ainda
            })),
          }
        : undefined,
    },
    include: { autor: true, anexos: true },
  });

  // Evento inicial de criação da solicitação (histórico/auditoria)
  try {
    await prisma.evento.create({
      data: {
        tipo: "CRIACAO",
        descricao: "Solicitação criada via app móvel.",
        antigoStatus: null,
        novoStatus: Status.NOVA,
        solicitacaoId: solicitacao.id,
        autorId: autorId ?? null,
      },
    });
  } catch (err) {
    // Não impedimos a criação da solicitação se o evento falhar;
    // apenas registramos no log.
    request.log.error(
      { err },
      "Falha ao registrar evento de criação de solicitação."
    );
  }

  const item = toApiSolicitacao(solicitacao);

  reply.code(201);
  return {
    status: "ok",
    item,
  };
});

// Atualiza uma solicitação existente (status / descricao / atendimento)
app.patch("/solicitacoes/:id", async (request, reply) => {
  const { id } = request.params as { id: string };

  let body;
  try {
    body = updateSolicitacaoBody.parse(request.body ?? {});
  } catch (err) {
    request.log.error({ err }, "Body inválido em PATCH /solicitacoes/:id");
    return reply.status(400).send({
      error: "Dados inválidos para atualização de solicitação.",
    });
  }

  if (
    !body.status &&
    !body.descricao &&
    !body.atendimentoDescricao &&
    !body.atendimentoEncaminhamento &&
    !body.atendimentoStatus
  ) {
    return reply.status(400).send({
      error:
        "Nada para atualizar. Informe status, descricao ou dados de atendimento.",
    });
  }

  try {
    // 1) Carrega o registro atual para saber o status anterior
    const existing = await prisma.solicitacao.findUnique({
      where: { id },
    });

    if (!existing) {
      return reply.status(404).send({ error: "Solicitação não encontrada." });
    }

    // 2) Monta o objeto de atualização
    const dataToUpdate: any = {};

    if (body.status) {
      dataToUpdate.status = body.status as Status;
    }

    if (body.descricao) {
      dataToUpdate.descricao = body.descricao;
    }

    const updated = await prisma.solicitacao.update({
      where: { id },
      data: dataToUpdate,
      include: {
        autor: true,
        anexos: true,
      },
    });

    // 3) Decide o tipo de evento com base no que foi alterado
    let tipoEvento = "ATUALIZACAO";

    if (body.status && existing.status !== updated.status) {
      tipoEvento = "STATUS_CHANGE";
    } else if (body.atendimentoEncaminhamento) {
      tipoEvento = "ENCAMINHAMENTO";
    } else if (body.atendimentoStatus) {
      tipoEvento = "ATENDIMENTO";
    }

    // 4) Monta descrição consolidada do evento
    const partes: string[] = [];

    if (body.atendimentoEncaminhamento) {
      partes.push(`Encaminhado para: ${body.atendimentoEncaminhamento}`);
    }

    if (body.atendimentoStatus) {
      partes.push(`Status do atendimento: ${body.atendimentoStatus}`);
    }

    if (body.atendimentoDescricao) {
      partes.push(body.atendimentoDescricao);
    }

    if (body.descricao && !body.atendimentoDescricao) {
      partes.push(body.descricao);
    }

    const descricaoEvento =
      partes.length > 0 ? partes.join(" | ") : null;

    // 5) Registra evento de histórico/auditoria
    try {
      await prisma.evento.create({
        data: {
          tipo: tipoEvento,
          descricao: descricaoEvento,
          antigoStatus: existing.status,
          novoStatus: updated.status,
          solicitacaoId: updated.id,
          autorId: body.operadorId ?? null,
        },
      });
    } catch (err) {
      request.log.error(
        { err },
        "Falha ao registrar evento de atualização de solicitação."
      );
    }

    const item = toApiSolicitacao(updated);

    return reply.status(200).send({ status: "ok", item });
  } catch (err) {
    request.log.error(err);
    return reply
      .status(400)
      .send({ error: "Não foi possível atualizar a solicitação." });
  }
});

// Rota de debug para popular o banco com dados de exemplo
app.post("/debug/seed", async () => {
  const existing = await prisma.solicitacao.count();
  if (existing > 0) {
    return { status: "ok", message: "Já existem solicitações, seed ignorado." };
  }

  const autor = await prisma.usuario.upsert({
    where: { email: "cidadao_demo@cortapau.local" },
    update: {},
    create: {
      nome: "Cidadão Demo",
      email: "cidadao_demo@cortapau.local",
      hash: "demo-hash",
      role: Role.USER,
    },
  });

  const now = new Date();

  await prisma.solicitacao.createMany({
    data: [
      {
        id: undefined,
        titulo: "Risco Elétrico em escola",
        descricao: "Árvore encostando na fiação em frente à escola.",
        categoria: "RISCO_ELETRICO",
        status: "NOVA",
        latitude: -23.5505,
        longitude: -46.6333,
        autorId: autor.id,
        createdAt: new Date(now.getTime() - 60 * 60 * 1000),
        updatedAt: now,
        protocoloOficial: null,
        tags: [],
      },
      {
        id: undefined,
        titulo: "Risco de queda em via pública",
        descricao: "Árvore inclinada em direção à via pública.",
        categoria: "RISCO_QUEDAS",
        status: "EM_ATENDIMENTO",
        latitude: -23.5614,
        longitude: -46.6559,
        autorId: autor.id,
        createdAt: new Date(now.getTime() - 2 * 60 * 60 * 1000),
        updatedAt: now,
        protocoloOficial: null,
        tags: [],
      },
    ],
  });

  return { status: "ok", message: "Seed criado com sucesso." };
});

app.get(
  "/solicitacoes/:id/eventos",
  async (request, reply): Promise<ApiEventosResponse> => {
    const { id } = request.params as { id: string };

    // Verifica se a solicitação existe (opcional, mas ajuda a retornar 404 cedo)
    const exists = await prisma.solicitacao.findUnique({
      where: { id },
      select: { id: true },
    });

    if (!exists) {
      reply.status(404);
      return {
        status: "error",
        items: [],
      };
    }

    const eventos = await prisma.evento.findMany({
      where: { solicitacaoId: id },
      orderBy: { createdAt: "asc" },
      include: { autor: true },
    });

    const items = eventos.map(toApiEvento);

    return {
      status: "ok",
      items,
    };
  }
);

// --- Inicialização ---

const PORT = Number(process.env.PORT ?? 3333);

app
  .listen({ port: PORT, host: "0.0.0.0" })
  .then(() => {
    console.log(`CortaPau API rodando em http://localhost:${PORT}`);
  })
  .catch((err) => {
    app.log.error(err);
    process.exit(1);
  });
