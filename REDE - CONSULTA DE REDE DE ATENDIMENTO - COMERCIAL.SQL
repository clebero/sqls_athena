SELECT DISTINCT
    grupo_prestador,
    nome_prestador,
    nome_fantasia,
    cnpj_cpf,
    ccnespres,
    classificacao,
    crm,
    conselho,
    uf_conselho,
    id_especialidade,
    especialidade,
    logradouro,
    endereco,
    numero,
    complemento,
    bairro,
    cidade,
    uf,
    fone
FROM (
         ---- 1. Médicos SEM Local/Especialidade delimitando a Rede
         SELECT
             retorna_nome_grupo_prestador(f.cgruppres) AS grupo_prestador,
             f.cgruppres AS idgrupo,
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
             (SELECT t.cdesctlogr FROM hsstlogr t WHERE t.nnumetlogr = f.nnumetlogr) AS logradouro,
             f.cendepres AS endereco,
             f.cnendpres AS numero,
             f.ccomppres AS complemento,
             f.cbairpres AS bairro,
             f.ccidapres AS cidade,
             f.cestapres AS uf,
             icf_fone_pessoa(f.nnumepess) AS fone,
             sp.nnumeplan AS id_plano,
             rp.nnumeredea AS id_rede,
             f.nnumepres AS id_prestador
         FROM solus.finpres f
                  JOIN hssprede pr ON pr.nnumepres = f.nnumepres
                  JOIN hssespre es ON es.nnumepres = f.nnumepres
                  JOIN hssredpl rp ON rp.nnumeredea = pr.nnumeredea
                  JOIN hssplan  sp ON sp.nnumeplan  = rp.nnumeplan
         WHERE f.ccredpres   = 'S'
           AND pr.dfinaprede IS NULL
           AND es.cpublespre = 'S'
           AND pr.cpwebprede = 'S'
           AND f.cpesspres   = 'F'
           AND pr.nnumeespec IS NULL

         UNION ALL

         ---- 2. Médicos SEM Local e COM Especialidades delimitando a Rede
         SELECT DISTINCT
             retorna_nome_grupo_prestador(f.cgruppres), f.cgruppres, f.cnomepres, f.cfantpres,
             NVL(f.ccgc_pres, f.ccpf_pres), f.ccnespres, retorna_classif_prestador(f.nnumeclapr),
             TO_CHAR(f.ncrm_pres), f.cconspres || ' ' || f.cufcrpres, f.cufcrpres,
             es.nnumeespec, TO_CHAR(retorna_nome_especialidade(es.nnumeespec)),
             (SELECT t.cdesctlogr FROM hsstlogr t WHERE t.nnumetlogr = f.nnumetlogr),
             f.cendepres, f.cnendpres, f.ccomppres, f.cbairpres, f.ccidapres, f.cestapres,
             icf_fone_pessoa(f.nnumepess), sp.nnumeplan, rp.nnumeredea, f.nnumepres
         FROM solus.finpres f
                  JOIN hssprede pr ON pr.nnumepres = f.nnumepres
                  JOIN hssespre es ON es.nnumepres = f.nnumepres
                  JOIN hssredpl rp ON rp.nnumeredea = pr.nnumeredea
                  JOIN hssplan  sp ON sp.nnumeplan  = rp.nnumeplan
         WHERE f.ccredpres     = 'S'
           AND pr.dfinaprede  IS NULL
           AND es.cpublespre   = 'S'
           AND es.nnumeepres  IS NULL
           AND pr.cpwebprede   = 'S'
           AND f.cpesspres     = 'F'
           AND pr.nnumeespec  IS NOT NULL

         UNION ALL

         ---- 3. Médicos SEM Especialidades (Corpo Clínico PJ)
         SELECT
             retorna_nome_grupo_prestador(cc.cgruppres), cc.cgruppres, cc.cnomepres, cc.cfantpres,
             NVL(cc.ccgc_pres, cc.ccpf_pres), cc.ccnespres, retorna_classif_prestador(cc.nnumeclapr),
             TO_CHAR(cc.ncrm_pres), cc.cconspres || ' ' || f.cufcrpres, cc.cufcrpres,
             cl.nnumeespec, TO_CHAR(retorna_nome_especialidade(cl.nnumeespec)),
             (SELECT t.cdesctlogr FROM hsstlogr t WHERE t.nnumetlogr = f.nnumetlogr),
             f.cendepres, f.cnendpres, f.ccomppres, f.cbairpres, f.ccidapres, f.cestapres,
             icf_fone_pessoa(f.nnumepess), sp.nnumeplan, rp.nnumeredea, cc.nnumepres
         FROM solus.finpres f
                  JOIN hsscclin cl ON cl.nhosppres = f.nnumepres
                  JOIN finpres cc  ON cl.nnumepres = cc.nnumepres
                  JOIN hssespre es ON es.nnumeespec = cl.nnumeespec AND es.nnumepres = f.nnumepres
                  JOIN hssprede pr ON pr.nnumepres  = f.nnumepres
                  JOIN hssredpl rp ON rp.nnumeredea = pr.nnumeredea
                  JOIN hssplan  sp ON sp.nnumeplan  = rp.nnumeplan
         WHERE pr.dfinaprede  IS NULL
           AND es.nnumeepres  IS NULL
           AND cl.cstatcclin   = 'A'
           AND cl.cpublcclin   = 'S'
           AND es.cpublespre   = 'S'
           AND pr.cpwebprede   = 'S'
           AND f.cgruppres    <> 'E'
           AND f.cpesspres     = 'J'
           AND pr.nnumeespec  IS NULL

         UNION ALL

         ---- 4. Médicos x Empresa Médica SEM Especialidades
         SELECT
             retorna_nome_grupo_prestador(cc.cgruppres), cc.cgruppres, cc.cnomepres, cc.cfantpres,
             NVL(cc.ccgc_pres, cc.ccpf_pres), cc.ccnespres, retorna_classif_prestador(cc.nnumeclapr),
             TO_CHAR(cc.ncrm_pres), cc.cconspres || ' ' || f.cufcrpres, cc.cufcrpres,
             cl.nnumeespec, TO_CHAR(retorna_nome_especialidade(cl.nnumeespec)),
             (SELECT t.cdesctlogr FROM hsstlogr t WHERE t.nnumetlogr = f.nnumetlogr),
             cc.cendepres, cc.cnendpres, cc.ccomppres, cc.cbairpres, cc.ccidapres, cc.cestapres,
             icf_fone_pessoa(cc.nnumepess), sp.nnumeplan, rp.nnumeredea, cc.nnumepres
         FROM solus.finpres f
                  JOIN hsscclin cl ON cl.nhosppres  = f.nnumepres
                  JOIN finpres cc  ON cl.nnumepres  = cc.nnumepres
                  JOIN hssespre es ON es.nnumeespec = cl.nnumeespec AND es.nnumepres = cc.nnumepres
                  JOIN hssprede pr ON pr.nnumepres  = cc.nnumepres
                  JOIN hssredpl rp ON rp.nnumeredea = pr.nnumeredea
                  JOIN hssplan  sp ON sp.nnumeplan  = rp.nnumeplan
         WHERE pr.dfinaprede  IS NULL
           AND es.nnumeepres  IS NULL
           AND cl.cstatcclin   = 'A'
           AND cl.cpublcclin   = 'S'
           AND es.cpublespre   = 'S'
           AND pr.cpwebprede   = 'S'
           AND f.cgruppres     = 'E'
           AND f.cpesspres     = 'J'
           AND pr.nnumeespec  IS NULL

         UNION ALL

         ---- 5. Médicos COM Especialidades delimitando a Rede
         SELECT
             retorna_nome_grupo_prestador(cc.cgruppres), cc.cgruppres, cc.cnomepres, cc.cfantpres,
             NVL(cc.ccgc_pres, cc.ccpf_pres), cc.ccnespres, retorna_classif_prestador(cc.nnumeclapr),
             TO_CHAR(cc.ncrm_pres), cc.cconspres || ' ' || f.cufcrpres, cc.cufcrpres,
             cl.nnumeespec, TO_CHAR(retorna_nome_especialidade(cl.nnumeespec)),
             (SELECT t.cdesctlogr FROM hsstlogr t WHERE t.nnumetlogr = f.nnumetlogr),
             f.cendepres, f.cnendpres, f.ccomppres, f.cbairpres, f.ccidapres, f.cestapres,
             icf_fone_pessoa(f.nnumepess), sp.nnumeplan, rp.nnumeredea, cc.nnumepres
         FROM solus.finpres f
                  JOIN hsscclin cl ON cl.nhosppres  = f.nnumepres
                  JOIN finpres cc  ON cl.nnumepres  = cc.nnumepres
                  JOIN hssespre es ON es.nnumeespec = cl.nnumeespec AND es.nnumepres = f.nnumepres
                  JOIN hssprede pr ON pr.nnumepres  = f.nnumepres
             AND pr.nnumeespec = cl.nnumeespec
             AND pr.nnumeespec = es.nnumeespec
                  JOIN hssredpl rp ON rp.nnumeredea = pr.nnumeredea
                  JOIN hssplan  sp ON sp.nnumeplan  = rp.nnumeplan
         WHERE pr.dfinaprede  IS NULL
           AND es.nnumeepres  IS NULL
           AND cl.cstatcclin   = 'A'
           AND cl.cpublcclin   = 'S'
           AND es.cpublespre   = 'S'
           AND pr.cpwebprede   = 'S'
           AND f.cgruppres    <> 'E'
           AND f.cpesspres     = 'J'
           AND pr.nnumeespec  IS NOT NULL

         UNION ALL

         ---- 6. Médicos x Empresa Médica COM Especialidades
         SELECT
             retorna_nome_grupo_prestador(cc.cgruppres), cc.cgruppres, cc.cnomepres, cc.cfantpres,
             NVL(cc.ccgc_pres, cc.ccpf_pres), cc.ccnespres, retorna_classif_prestador(cc.nnumeclapr),
             TO_CHAR(cc.ncrm_pres), cc.cconspres || ' ' || f.cufcrpres, cc.cufcrpres,
             cl.nnumeespec, TO_CHAR(retorna_nome_especialidade(cl.nnumeespec)),
             (SELECT t.cdesctlogr FROM hsstlogr t WHERE t.nnumetlogr = f.nnumetlogr),
             cc.cendepres, cc.cnendpres, cc.ccomppres, cc.cbairpres, cc.ccidapres, cc.cestapres,
             icf_fone_pessoa(cc.nnumepess), sp.nnumeplan, rp.nnumeredea, cc.nnumepres
         FROM solus.finpres f
                  JOIN hsscclin cl ON cl.nhosppres  = f.nnumepres
                  JOIN finpres cc  ON cl.nnumepres  = cc.nnumepres
                  JOIN hssespre es ON es.nnumeespec = cl.nnumeespec AND es.nnumepres = cc.nnumepres
                  JOIN hssprede pr ON pr.nnumepres  = cc.nnumepres
             AND pr.nnumeespec = cl.nnumeespec
             AND pr.nnumeespec = es.nnumeespec
                  JOIN hssredpl rp ON rp.nnumeredea = pr.nnumeredea
                  JOIN hssplan  sp ON sp.nnumeplan  = rp.nnumeplan
         WHERE pr.dfinaprede  IS NULL
           AND es.nnumeepres  IS NULL
           AND cl.cstatcclin   = 'A'
           AND cl.cpublcclin   = 'S'
           AND es.cpublespre   = 'S'
           AND pr.cpwebprede   = 'S'
           AND f.cgruppres     = 'E'
           AND f.cpesspres     = 'J'
           AND pr.nnumeespec  IS NOT NULL

         UNION ALL

         ---- 7. Locais de Atendimentos SEM Especialidades
         SELECT
             retorna_nome_grupo_prestador(f.cgruppres), f.cgruppres, f.cfantpres, f.cfantpres,
             NVL(f.ccgc_pres, f.ccpf_pres), f.ccnespres, retorna_classif_prestador(f.nnumeclapr),
             '', '', '', es.nnumeespec, TO_CHAR(retorna_nome_especialidade(es.nnumeespec)),
             (SELECT t.cdesctlogr FROM hsstlogr t WHERE t.nnumetlogr = f.nnumetlogr),
             f.cendepres, f.cnendpres, f.ccomppres, f.cbairpres, f.ccidapres, f.cestapres,
             icf_fone_pessoa(f.nnumepess), sp.nnumeplan, rp.nnumeredea, f.nnumepres
         FROM solus.finpres f
                  JOIN hssespre es ON es.nnumepres = f.nnumepres
                  JOIN hssprede pr ON pr.nnumepres = f.nnumepres
                  JOIN hssredpl rp ON rp.nnumeredea = pr.nnumeredea
                  JOIN hssplan  sp ON sp.nnumeplan  = rp.nnumeplan
         WHERE pr.dfinaprede  IS NULL
           AND es.nnumeepres  IS NULL
           AND pr.cpwebprede   = 'S'
           AND es.cpublespre   = 'S'
           AND f.cpesspres     = 'J'
           AND pr.nnumeespec  IS NULL

         UNION ALL

         ---- 8. Locais de Atendimentos COM Especialidades
         SELECT
             retorna_nome_grupo_prestador(f.cgruppres), f.cgruppres, f.cfantpres, f.cfantpres,
             NVL(f.ccgc_pres, f.ccpf_pres), f.ccnespres, retorna_classif_prestador(f.nnumeclapr),
             '', '', '', es.nnumeespec, TO_CHAR(retorna_nome_especialidade(es.nnumeespec)),
             (SELECT t.cdesctlogr FROM hsstlogr t WHERE t.nnumetlogr = f.nnumetlogr),
             f.cendepres, f.cnendpres, f.ccomppres, f.cbairpres, f.ccidapres, f.cestapres,
             icf_fone_pessoa(f.nnumepess), sp.nnumeplan, rp.nnumeredea, f.nnumepres
         FROM solus.finpres f
                  JOIN hssespre es ON es.nnumepres  = f.nnumepres
                  JOIN hssprede pr ON pr.nnumepres  = f.nnumepres
             AND pr.nnumeespec = es.nnumeespec
                  JOIN hssredpl rp ON rp.nnumeredea = pr.nnumeredea
                  JOIN hssplan  sp ON sp.nnumeplan  = rp.nnumeplan
         WHERE pr.dfinaprede  IS NULL
           AND es.nnumeepres  IS NULL
           AND pr.cpwebprede   = 'S'
           AND es.cpublespre   = 'S'
           AND f.cpesspres     = 'J'
           AND pr.nnumeespec  IS NOT NULL
     ) v
WHERE v.id_plano      = :plano
  AND v.id_rede       = :rede
  AND v.id_prestador  = :prestador
  AND v.idgrupo       = :grupo
ORDER BY grupo_prestador, nome_prestador, especialidade


-- ============================================================
-- FILTROS
-- ============================================================

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

-- GRUPO
SELECT cvalodomin, cdispdomin
FROM hssdomin
WHERE ctipodomin = 'GRUPO_PRESTADOR'
  AND cstatdomin = 'A'
ORDER BY 2