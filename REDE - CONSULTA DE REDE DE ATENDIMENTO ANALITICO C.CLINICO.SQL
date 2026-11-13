WITH
-- 1. CONFIGURAÇÃO DA OPERADORA
vw_operadora AS (
    SELECT
        CASE
            WHEN UPPER(cnomeconf) LIKE '%NORDESTE%' THEN 'HUMANA NE'
            WHEN UPPER(cnomeconf) LIKE '%SUL%'      THEN 'HUMANA SUL'
            WHEN UPPER(cnomeconf) LIKE '%SAMP%'     THEN 'SAMP SBS'
            END AS nome_operadora
    FROM hssconf
    WHERE ROWNUM = 1
),

-- 2. FILTRO PRINCIPAL + REDE (explodido: 1 linha por prestador x rede)
vw_prestadores_base AS (
    SELECT /*+ MATERIALIZE */ DISTINCT
        rb.cnomeredea,
        f.nnumepres,
        f.nnumepess,
        f.ccodipres,
        f.cpesspres,
        NVL(f.ccgc_pres, f.ccpf_pres) AS cnpj_cpf,
        f.cnomepres,
        f.cfantpres,
        f.cgruppres,
        f.nnumeclapr,
        f.ccredpres,
        DECODE(f.ccredpres,
               'S', 'Credenciado',
               'O', 'Cooperado',
               'N', 'Não credenciado/Descredenciado',
               'M', 'Ex-Cooperado/Não credenciado',
               'R', 'Somente para fins de reembolso',
               'A', 'Somente para atendimentos Abramge',
               'C', 'Somente para corpo clinico',
               'F', 'Somente para fins de recebimento',
               'X', 'Credenciado suspenso',
               'B', 'Cooperado suspenso',
               'V', 'Negociação avulsa',
               'Z', 'Aguardando inclusão',
               'I', 'Somente para fins de solicitação',
               'Não identificado (' || f.ccredpres || ')'
        ) AS situacao,
        emp.nome_empresa_medica,
        nvl(an.cncomusua, an.cnomeusua) AS analista_responsavel
    FROM hssredea rb
             JOIN hssprede pr ON pr.nnumeredea = rb.nnumeredea
             JOIN finpres f   ON f.nnumepres = pr.nnumepres
             LEFT JOIN segusua an ON an.nnumeusua = f.nancmusua
             LEFT JOIN (
        SELECT nnumepres, nome_empresa_medica
        FROM (
                 SELECT
                     c.nnumepres,
                     f2.cnomepres AS nome_empresa_medica,
                     ROW_NUMBER() OVER (PARTITION BY c.nnumepres ORDER BY c.diniccalen DESC) AS rn
                 FROM hsscalen c
                          JOIN finpres f2 ON f2.nnumepres = c.nemprpres
                 WHERE TRUNC(SYSDATE) BETWEEN c.diniccalen AND NVL(c.dfinacalen, SYSDATE)
             )
        WHERE rn = 1
    ) emp ON emp.nnumepres = f.nnumepres
    WHERE f.cgruppres   = :GRUPO_PRESTADOR
      AND rb.nnumeredea = :REDE
),

-- 3. AGREGAÇÕES DE GUIAS E LOTES (1:1 por prestador)
vw_lote_6m AS (
    SELECT
        l.nnumepres,
        SUM(l.nvalolote) AS apresentado_ultimos6m
    FROM hsslote l
    WHERE l.csitulote = 'F'
      AND l.dcomplote >= TRUNC(ADD_MONTHS(SYSDATE, -6), 'MM')
      AND EXISTS (SELECT 1 FROM vw_prestadores_base pb WHERE pb.nnumepres = l.nnumepres)
    GROUP BY l.nnumepres
),
vw_guia_exec_6m AS (
    SELECT
        g.nnumepres,
        COUNT(*) AS qtd_guias_executante6m
    FROM hssguia g
    WHERE NVL(g.cstatguia, 'L') = 'L'
      AND g.demisguia >= TRUNC(ADD_MONTHS(SYSDATE, -6), 'MM')
      AND EXISTS (SELECT 1 FROM vw_prestadores_base pb WHERE pb.nnumepres = g.nnumepres)
    GROUP BY g.nnumepres
),
vw_guia_local_6m AS (
    SELECT
        g.nlocapres,
        COUNT(*) AS qtd_guias_localatend6m
    FROM hssguia g
    WHERE NVL(g.cstatguia, 'L') = 'L'
      AND g.demisguia >= TRUNC(ADD_MONTHS(SYSDATE, -6), 'MM')
      AND EXISTS (SELECT 1 FROM vw_prestadores_base pb WHERE pb.nnumepres = g.nlocapres)
    GROUP BY g.nlocapres
),

-- 4. DESDUPLICAÇÃO (1:1 por pessoa/prestador)
vw_telefone AS (
    SELECT
        nnumepess,
        MAX(cddd_fonp || ' ' || cfonefonp) AS FONE
    FROM hssfonp
    WHERE cstatfonp = 'A'
      AND cprinfonp = 'S'
      AND EXISTS (SELECT 1 FROM vw_prestadores_base pb WHERE pb.nnumepess = hssfonp.nnumepess)
    GROUP BY nnumepess
),

-- Endereço do prestador principal:
-- prioridade: tipo Atendimento ('A'); fallback: endereço principal quando não há tipo 'A'
vw_endereco AS (
    SELECT
        en.nnumepess,
        DECODE(en.ctipoendp,
               'A', 'Atendimento',
               'D', 'Administrativo',
               'R', 'Residencial',
               'F', 'Faturamento',
               'C', 'Comercial',
               'P', 'Correspondência',
               'N', 'Nota fiscal',
               'M', 'Atendimento domiciliar') AS TIPO_ENDERECO,
        en.ccidaendp  AS CIDADE,
        en.cestaendp  AS ESTADO,
        en.nnumetlogr,
        en.cendeendp  AS ENDERECO,
        en.cnumeendp  AS NUMERO,
        en.cbairendp  AS BAIRRO,
        en.ccompendp  AS COMPLEMENTO
    FROM hssendp en
    WHERE en.cstatendp = 'A'
      AND en.ctipoendp = 'A'
      AND EXISTS (SELECT 1 FROM vw_prestadores_base pb WHERE pb.nnumepess = en.nnumepess)
    UNION ALL
    SELECT
        en.nnumepess,
        DECODE(en.ctipoendp,
               'A', 'Atendimento',
               'D', 'Administrativo',
               'R', 'Residencial',
               'F', 'Faturamento',
               'C', 'Comercial',
               'P', 'Correspondência',
               'N', 'Nota fiscal',
               'M', 'Atendimento domiciliar') AS TIPO_ENDERECO,
        en.ccidaendp  AS CIDADE,
        en.cestaendp  AS ESTADO,
        en.nnumetlogr,
        en.cendeendp  AS ENDERECO,
        en.cnumeendp  AS NUMERO,
        en.cbairendp  AS BAIRRO,
        en.ccompendp  AS COMPLEMENTO
    FROM hssendp en
    WHERE en.cstatendp = 'A'
      AND en.cprinendp = 'S'
      AND EXISTS (SELECT 1 FROM vw_prestadores_base pb WHERE pb.nnumepess = en.nnumepess)
      AND NOT EXISTS (
        SELECT 1 FROM hssendp en2
        WHERE en2.nnumepess = en.nnumepess
          AND en2.ctipoendp = 'A'
          AND en2.cstatendp = 'A'
    )
),

-- 5. ESPECIALIDADES AGREGADAS
vw_especialidade AS (
    SELECT
        nnumepres,
        LISTAGG(cnomeespec, ' | ') WITHIN GROUP (ORDER BY cnomeespec) AS especialidades
FROM (
    SELECT DISTINCT ep.nnumepres, e.cnomeespec
    FROM hssespre ep
    JOIN hssespec e ON e.nnumeespec = ep.nnumeespec
    WHERE EXISTS (SELECT 1 FROM vw_prestadores_base pb WHERE pb.nnumepres = ep.nnumepres)
    )
GROUP BY nnumepres
    ),
    vw_email7 AS (
SELECT
    nnumepres,
    MAX(cnomeemapr) AS EMAIL7_CONTATO,
    MAX(cdescemapr) AS EMAIL7_SETOR,
    MAX(cprinemapr) AS EMAIL7_SN_PRINC,
    MAX(cemaiemapr) AS EMAIL7
FROM hssemapr
WHERE EXISTS (SELECT 1 FROM vw_prestadores_base pb WHERE pb.nnumepres = hssemapr.nnumepres)
GROUP BY nnumepres
    ),
    vw_email_pessoa AS (
SELECT
    nnumepess,
    MAX(cmailemap) AS max_email
FROM hssemap
WHERE cprinemap = 'S'
  AND cstatemap = 'A'
  AND EXISTS (SELECT 1 FROM vw_prestadores_base pb WHERE pb.nnumepess = hssemap.nnumepess)
GROUP BY nnumepess
    ),

-- 6. CORPO CLÍNICO (explodido: 1 linha por médico do corpo clínico)
    vw_corpo_clinico AS (
SELECT /*+ MATERIALIZE */ DISTINCT
    c.nhosppres AS id_hospital,
    p.ccodipres AS cod_corpo_clinico,
    p.cpesspres AS natureza_corpo_clinico,
    NVL(p.ccpf_pres, p.ccgc_pres) AS cnpj_cpf_corpo_clinico,
    p.cconspres AS conselho_corpo_clinico,
    p.ncrm_pres AS nr_conselho_corpo_clinico,
    p.cufcrpres AS uf_crm_corpo_clinico,
    p.cnomepres AS nome_corpo_clinico,
    p.cfantpres AS fantasia_corpo_clinico,
    DECODE(p.ccredpres,
    'S', 'Credenciado',
    'O', 'Cooperado',
    'N', 'Não credenciado/Descredenciado',
    'M', 'Ex-Cooperado/Não credenciado',
    'R', 'Somente para fins de reembolso',
    'A', 'Somente para atendimentos Abramge',
    'C', 'Somente para corpo clinico',
    'F', 'Somente para fins de recebimento',
    'X', 'Credenciado suspenso',
    'B', 'Cooperado suspenso',
    'V', 'Negociação avulsa',
    'Z', 'Aguardando inclusão',
    'I', 'Somente para fins de solicitação',
    'Não identificado (' || p.ccredpres || ')'
    ) AS situacao_corpo_clinico,
    retorna_nome_grupo_prestador(p.cgruppres) AS grupo_corpo_clinico,
    cp.cdescclapr AS classificacao_corpo_clinico,
    en.ccidaendp  AS cidade_corpo_clinico,
    en.cestaendp  AS estado_corpo_clinico,
    tl.cdesctlogr AS logradouro_corpo_clinico,
    en.cendeendp  AS endereco_corpo_clinico,
    en.cnumeendp  AS numero_corpo_clinico,
    en.cbairendp  AS bairro_corpo_clinico,
    en.ccompendp  AS complemento_corpo_clinico,
    (fo.cddd_fonp || ' ' || fo.cfonefonp) AS fone_corpo_clinico,
    e.nnumeespec  AS id_espec_corpo_clinico,
    e.cnomeespec  AS especialidade_corpo_clinico,
    es.cpublespre AS publica_corpo_clinico,
    c.cstatcclin  AS status_corpo_clinico
FROM hsscclin c
    JOIN finpres p    ON p.nnumepres = c.nnumepres
    JOIN hssespre es  ON es.nnumepres = c.nnumepres
    JOIN hssespec e   ON e.nnumeespec = es.nnumeespec
    LEFT JOIN hssclapr cp ON cp.nnumeclapr = p.nnumeclapr
    -- Endereço do corpo clínico: mesma lógica de prioridade
    LEFT JOIN (
    SELECT nnumepess, ctipoendp, ccidaendp, cestaendp, nnumetlogr,
    cendeendp, cnumeendp, cbairendp, ccompendp
    FROM hssendp
    WHERE cstatendp = 'A'
    AND ctipoendp = 'A'
    UNION ALL
    SELECT nnumepess, ctipoendp, ccidaendp, cestaendp, nnumetlogr,
    cendeendp, cnumeendp, cbairendp, ccompendp
    FROM hssendp h2
    WHERE h2.cstatendp = 'A'
    AND h2.cprinendp = 'S'
    AND NOT EXISTS (
    SELECT 1 FROM hssendp h3
    WHERE h3.nnumepess = h2.nnumepess
    AND h3.ctipoendp = 'A'
    AND h3.cstatendp = 'A'
    )
    ) en ON en.nnumepess = p.nnumepess
    LEFT JOIN hsstlogr tl ON tl.nnumetlogr = en.nnumetlogr
    LEFT JOIN hssfonp fo  ON fo.nnumepess = p.nnumepess
    AND fo.cstatfonp = 'A'
    AND fo.cprinfonp = 'S'
WHERE NVL(c.cstatcclin, 'I') = 'A'
  AND EXISTS (
    SELECT 1 FROM vw_prestadores_base pb
    WHERE pb.nnumepres = c.nhosppres
  AND pb.cpesspres = 'J'
    )
    )

-- ==========================================================================
-- QUERY PRINCIPAL
-- ==========================================================================
SELECT
    op.nome_operadora                           AS OPERADORA,
    pb.cnomeredea                               AS REDE_ATENDIMENTO,
    pb.ccodipres                                AS CODIGO_PRESTADOR,
    pb.cpesspres                                AS NATUREZA,
    pb.cnpj_cpf                                 AS CNPJ_CPF,
    pb.cnomepres                                AS RAZAO_SOCIAL,
    pb.cfantpres                                AS NOME_FANTASIA,
    pb.situacao                                 AS SITUACAO,
    d.cdispdomin                                AS GRUPO,
    cp.cdescclapr                               AS CLASSIFICACAO,
    pb.nome_empresa_medica                      AS EMPRESA_MEDICA,
    NVL(l6.apresentado_ultimos6m, 0)            AS APRESENTADO_ULTIMOS6M,
    NVL(ge6.qtd_guias_executante6m, 0)          AS QTD_GUIAS_EXECUTANTE6M,
    NVL(gl6.qtd_guias_localatend6m, 0)          AS QTD_GUIAS_LOCALATEND6M,
    endp.TIPO_ENDERECO,
    endp.CIDADE,
    endp.ESTADO,
    tl_pres.cdesctlogr                          AS LOGRADOURO,
    endp.ENDERECO,
    endp.NUMERO,
    endp.BAIRRO,
    endp.COMPLEMENTO,
    tel.FONE,
    esp.especialidades                          AS ESPECIALIDADES,
    pb.analista_responsavel,
    co.cod_corpo_clinico,
    co.natureza_corpo_clinico,
    co.cnpj_cpf_corpo_clinico,
    co.nome_corpo_clinico,
    co.fantasia_corpo_clinico,
    co.conselho_corpo_clinico,
    co.nr_conselho_corpo_clinico,
    co.uf_crm_corpo_clinico,
    co.situacao_corpo_clinico                   AS SITUACAO_CORPO_CLINICO,
    co.grupo_corpo_clinico,
    co.classificacao_corpo_clinico              AS CLASSIFICACAO_CORPO_CLINICO,
    co.cidade_corpo_clinico,
    co.estado_corpo_clinico,
    co.logradouro_corpo_clinico,
    co.endereco_corpo_clinico,
    co.numero_corpo_clinico,
    co.bairro_corpo_clinico,
    co.complemento_corpo_clinico,
    co.fone_corpo_clinico,
    co.id_espec_corpo_clinico,
    co.especialidade_corpo_clinico,
    co.publica_corpo_clinico,
    co.status_corpo_clinico,
    em.max_email                                AS EMAIL_PESSOA,
    mail.EMAIL7_CONTATO,
    mail.EMAIL7_SETOR,
    mail.EMAIL7_SN_PRINC,
    mail.EMAIL7
FROM vw_prestadores_base pb
         CROSS JOIN vw_operadora op
         LEFT JOIN hssdomin d           ON d.ctipodomin = 'GRUPO_PRESTADOR' AND d.cvalodomin = pb.cgruppres
         LEFT JOIN hssclapr cp          ON cp.nnumeclapr = pb.nnumeclapr
         LEFT JOIN vw_endereco endp     ON endp.nnumepess = pb.nnumepess
         LEFT JOIN hsstlogr tl_pres     ON tl_pres.nnumetlogr = endp.nnumetlogr
         LEFT JOIN vw_telefone tel      ON tel.nnumepess = pb.nnumepess
         LEFT JOIN vw_especialidade esp ON esp.nnumepres = pb.nnumepres
         LEFT JOIN vw_email7 mail       ON mail.nnumepres = pb.nnumepres
         LEFT JOIN vw_corpo_clinico co  ON co.id_hospital = pb.nnumepres
         LEFT JOIN vw_lote_6m l6        ON l6.nnumepres = pb.nnumepres
         LEFT JOIN vw_guia_exec_6m ge6  ON ge6.nnumepres = pb.nnumepres
         LEFT JOIN vw_guia_local_6m gl6 ON gl6.nlocapres = pb.nnumepres
         LEFT JOIN vw_email_pessoa em   ON em.nnumepess = pb.nnumepess
ORDER BY CODIGO_PRESTADOR, REDE_ATENDIMENTO, ESPECIALIDADES, COD_CORPO_CLINICO


-- ============================================================
-- FILTROS
-- ============================================================

-- REDE
SELECT nnumeredea, cnomeredea
FROM hssredea
ORDER BY 2

-- GRUPO_PRESTADOR
SELECT d.cvalodomin, d.cdispdomin
FROM hssdomin d
WHERE d.ctipodomin = 'GRUPO_PRESTADOR'
ORDER BY 2