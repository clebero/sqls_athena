WITH
-- Endereço com prioridade: tipo Atendimento ('A'); fallback principal quando não há tipo 'A'
-- ROW_NUMBER garante 1 registro por pessoa quando há múltiplos endereços tipo 'A'
vw_endereco AS (
    SELECT nnumepess, logradouro, endereco, numero, complemento, bairro, cidade, uf
    FROM (
             SELECT en.nnumepess,
                    (SELECT t.cdesctlogr FROM hsstlogr t WHERE t.nnumetlogr = en.nnumetlogr) AS logradouro,
                    en.cendeendp AS endereco,
                    en.cnumeendp AS numero,
                    en.ccompendp AS complemento,
                    en.cbairendp AS bairro,
                    en.ccidaendp AS cidade,
                    en.cestaendp AS uf,
                    ROW_NUMBER() OVER (PARTITION BY en.nnumepess ORDER BY en.nnumetlogr) AS rn
             FROM hssendp en
             WHERE en.cstatendp = 'A'
               AND en.ctipoendp = 'A'
             UNION ALL
             SELECT en.nnumepess,
                    (SELECT t.cdesctlogr FROM hsstlogr t WHERE t.nnumetlogr = en.nnumetlogr),
                    en.cendeendp, en.cnumeendp, en.ccompendp, en.cbairendp, en.ccidaendp, en.cestaendp,
                    ROW_NUMBER() OVER (PARTITION BY en.nnumepess ORDER BY en.nnumetlogr)
             FROM hssendp en
             WHERE en.cstatendp = 'A'
               AND en.cprinendp = 'S'
               AND NOT EXISTS (
                 SELECT 1 FROM hssendp en2
                 WHERE en2.nnumepess = en.nnumepess
                   AND en2.ctipoendp = 'A'
                   AND en2.cstatendp = 'A'
             )
         )
    WHERE rn = 1
),
BaseRede AS (
    SELECT
        pr.nnumepres,
        pr.nnumeespec AS espec_rede,
        rp.nnumeplan,
        rp.nnumeredea
    FROM hssprede pr
             JOIN hssredpl rp ON rp.nnumeredea = pr.nnumeredea
    WHERE pr.dfinaprede IS NULL
      AND pr.cpwebprede = 'S'
      AND rp.nnumeplan  = :plano
      AND rp.nnumeredea = :rede
)
SELECT DISTINCT
    v.grupo_prestador,
    v.nome_prestador,
    v.nome_fantasia,
    v.cnpj_cpf,
    v.ccnespres,
    v.classificacao,
    v.crm,
    v.conselho,
    v.uf_conselho,
    v.id_especialidade,
    v.especialidade,
    v.logradouro,
    v.endereco,
    v.numero,
    v.complemento,
    v.bairro,
    v.cidade,
    v.uf,
    v.fone,
    v.corpo_clinico
FROM (
         ---- BLOCO 1: Médicos PF
         SELECT
             retorna_nome_grupo_prestador(f.cgruppres) AS grupo_prestador,
             f.cgruppres AS idgrupo,
             f.nnumepres AS id_prestador,
             f.cnomepres AS nome_prestador,
             f.cfantpres AS nome_fantasia,
             NVL(f.ccgc_pres, f.ccpf_pres) AS cnpj_cpf,
             f.ccnespres,
             retorna_classif_prestador(f.nnumeclapr) AS classificacao,
             TO_CHAR(f.ncrm_pres) AS crm,
             f.cconspres || ' ' || f.cufcrpres AS conselho,
             f.cufcrpres AS uf_conselho,
             es.nnumeespec AS id_especialidade,
             TO_CHAR(retorna_nome_especialidade(es.nnumeespec)) AS especialidade,
             end_f.logradouro,
             end_f.endereco,
             end_f.numero,
             end_f.complemento,
             end_f.bairro,
             end_f.cidade,
             end_f.uf,
             icf_fone_pessoa(f.nnumepess) AS fone,
             f.cnomepres AS corpo_clinico
         FROM solus.finpres f
                  JOIN BaseRede b   ON b.nnumepres  = f.nnumepres
                  JOIN hssespre es  ON es.nnumepres = f.nnumepres
                  LEFT JOIN vw_endereco end_f ON end_f.nnumepess = f.nnumepess
         WHERE f.ccredpres = 'S'
           AND f.cpesspres = 'F'
           AND es.cpublespre = 'S'
           AND (b.espec_rede IS NULL OR b.espec_rede = es.nnumeespec)

         UNION ALL

         ---- BLOCO 2: Corpo Clínico PJ Normal
         SELECT
             retorna_nome_grupo_prestador(cc.cgruppres),
             cc.cgruppres,
             cc.nnumepres,
             cc.cnomepres,
             cc.cfantpres,
             NVL(cc.ccgc_pres, cc.ccpf_pres),
             cc.ccnespres,
             retorna_classif_prestador(cc.nnumeclapr),
             TO_CHAR(cc.ncrm_pres),
             cc.cconspres || ' ' || f.cufcrpres,
             cc.cufcrpres,
             cl.nnumeespec,
             TO_CHAR(retorna_nome_especialidade(cl.nnumeespec)),
             end_f.logradouro,
             end_f.endereco,
             end_f.numero,
             end_f.complemento,
             end_f.bairro,
             end_f.cidade,
             end_f.uf,
             icf_fone_pessoa(f.nnumepess),
             cc.cnomepres
         FROM solus.finpres f
                  JOIN BaseRede b   ON b.nnumepres  = f.nnumepres
                  JOIN hsscclin cl  ON cl.nhosppres = f.nnumepres
                  JOIN solus.finpres cc ON cl.nnumepres = cc.nnumepres
                  JOIN hssespre es  ON es.nnumeespec = cl.nnumeespec AND es.nnumepres = f.nnumepres
                  LEFT JOIN vw_endereco end_f ON end_f.nnumepess = f.nnumepess
         WHERE f.cpesspres     = 'J'
           AND f.cgruppres    <> 'E'
           AND cl.cstatcclin   = 'A'
           AND cl.cpublcclin   = 'S'
           AND es.cpublespre   = 'S'
           AND (b.espec_rede IS NULL OR b.espec_rede = cl.nnumeespec)

         UNION ALL

         ---- BLOCO 3: Corpo Clínico Empresa Médica
         SELECT
             retorna_nome_grupo_prestador(cc.cgruppres),
             cc.cgruppres,
             cc.nnumepres,
             cc.cnomepres,
             cc.cfantpres,
             NVL(cc.ccgc_pres, cc.ccpf_pres),
             cc.ccnespres,
             retorna_classif_prestador(cc.nnumeclapr),
             TO_CHAR(cc.ncrm_pres),
             cc.cconspres || ' ' || f.cufcrpres,
             cc.cufcrpres,
             cl.nnumeespec,
             TO_CHAR(retorna_nome_especialidade(cl.nnumeespec)),
             end_cc.logradouro,
             end_cc.endereco,
             end_cc.numero,
             end_cc.complemento,
             end_cc.bairro,
             end_cc.cidade,
             end_cc.uf,
             icf_fone_pessoa(cc.nnumepess),
             cc.cnomepres
         FROM solus.finpres f
                  JOIN hsscclin cl  ON cl.nhosppres = f.nnumepres
                  JOIN solus.finpres cc ON cl.nnumepres = cc.nnumepres
                  JOIN BaseRede b   ON b.nnumepres  = cc.nnumepres
                  JOIN hssespre es  ON es.nnumeespec = cl.nnumeespec AND es.nnumepres = cc.nnumepres
                  LEFT JOIN vw_endereco end_cc ON end_cc.nnumepess = cc.nnumepess
         WHERE f.cpesspres     = 'J'
           AND f.cgruppres     = 'E'
           AND cl.cstatcclin   = 'A'
           AND cl.cpublcclin   = 'S'
           AND es.cpublespre   = 'S'
           AND (b.espec_rede IS NULL OR b.espec_rede = cl.nnumeespec)

         UNION ALL

         ---- BLOCO 4: Locais de Atendimento
         SELECT
             retorna_nome_grupo_prestador(f.cgruppres),
             f.cgruppres,
             f.nnumepres,
             f.cfantpres,
             f.cfantpres,
             NVL(f.ccgc_pres, f.ccpf_pres),
             f.ccnespres,
             retorna_classif_prestador(f.nnumeclapr),
             '', '', '',
             es.nnumeespec,
             TO_CHAR(retorna_nome_especialidade(es.nnumeespec)),
             end_f.logradouro,
             end_f.endereco,
             end_f.numero,
             end_f.complemento,
             end_f.bairro,
             end_f.cidade,
             end_f.uf,
             icf_fone_pessoa(f.nnumepess),
             cc_lin.cnomepres
         FROM solus.finpres f
                  JOIN BaseRede b   ON b.nnumepres  = f.nnumepres
                  JOIN hssespre es  ON es.nnumepres = f.nnumepres
                  LEFT JOIN hsscclin cl_lin   ON cl_lin.nhosppres = f.nnumepres
             AND cl_lin.cpublcclin = 'S'
             AND cl_lin.cstatcclin = 'A'
                  LEFT JOIN solus.finpres cc_lin ON cl_lin.nnumepres = cc_lin.nnumepres
                  LEFT JOIN vw_endereco end_f    ON end_f.nnumepess  = f.nnumepess
         WHERE f.cpesspres   = 'J'
           AND es.cpublespre = 'S'
           AND (b.espec_rede IS NULL OR b.espec_rede = es.nnumeespec)
     ) v
WHERE v.id_prestador = :prestador
  AND v.idgrupo      = :grupo
ORDER BY grupo_prestador, nome_prestador, especialidade


-- ============================================================
-- FILTROS
-- ============================================================

-- GRUPO
SELECT cvalodomin, cdispdomin
FROM hssdomin
WHERE ctipodomin = 'GRUPO_PRESTADOR'
  AND cstatdomin = 'A'
ORDER BY 2

-- PLANO
SELECT DISTINCT pl.nnumeplan,
                pl.ccodiplan || ' - ' || pl.cdescplan AS plano
FROM hssplan pl
ORDER BY 2

-- REDE
SELECT DISTINCT r.nnumeredea, r.cnomeredea
FROM hssredea r
WHERE r.csituredea = 'A'
  AND r.cprweredea = 'A'
  AND EXISTS (
    SELECT 1 FROM hssprede pr
    WHERE pr.nnumeredea = r.nnumeredea
)
ORDER BY 2

-- PRESTADOR
SELECT DISTINCT f.nnumepres,
                CASE WHEN f.cpesspres = 'F' THEN f.cnomepres ELSE f.cfantpres END AS nome
FROM finpres f
ORDER BY 2