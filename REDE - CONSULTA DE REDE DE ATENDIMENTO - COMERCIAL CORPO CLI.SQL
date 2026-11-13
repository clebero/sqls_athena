WITH BaseRede AS (
    SELECT
        pr.nnumepres,
        pr.nnumeespec AS espec_rede,
        rp.nnumeplan,
        rp.nnumeredea
    FROM hssprede pr
             JOIN hssredpl rp ON rp.nnumeredea = pr.nnumeredea
    WHERE pr.dfinaprede IS NULL
      AND pr.cpwebprede = 'S'
      AND rp.nnumeplan = :codigo_plano
      AND rp.nnumeplan = :registro
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
             retorna_nome_grupo_prestador(f.cgruppres) AS grupo_prestador, f.cgruppres AS idgrupo, f.nnumepres AS id_prestador,
             f.cnomepres AS nome_prestador, f.cfantpres AS nome_fantasia, NVL(f.ccgc_pres, f.ccpf_pres) AS cnpj_cpf,
             f.ccnespres, retorna_classif_prestador(f.nnumeclapr) AS classificacao, TO_CHAR(f.ncrm_pres) AS crm,
             f.cconspres || ' ' || f.cufcrpres AS conselho, f.cufcrpres AS uf_conselho, es.nnumeespec AS id_especialidade,
             TO_CHAR(retorna_nome_especialidade(es.nnumeespec)) AS especialidade,
             (SELECT t.cdesctlogr FROM hsstlogr t WHERE t.nnumetlogr = f.nnumetlogr) AS logradouro,
             f.cendepres AS endereco, f.cnendpres AS numero, f.ccomppres AS complemento,
             f.cbairpres AS bairro, f.ccidapres AS cidade, f.cestapres AS uf,
             icf_fone_pessoa(f.nnumepess) AS fone, f.cnomepres AS corpo_clinico
         FROM solus.finpres f
                  JOIN BaseRede b ON b.nnumepres = f.nnumepres
                  JOIN hssespre es ON es.nnumepres = f.nnumepres
         WHERE f.ccredpres = 'S' AND f.cpesspres = 'F' AND es.cpublespre = 'S'
           AND (b.espec_rede IS NULL OR b.espec_rede = es.nnumeespec)

         UNION ALL

         ---- BLOCO 2: Corpo Clínico PJ Normal
         SELECT
             retorna_nome_grupo_prestador(cc.cgruppres), cc.cgruppres, cc.nnumepres, cc.cnomepres, cc.cfantpres,
             NVL(cc.ccgc_pres, cc.ccpf_pres), cc.ccnespres, retorna_classif_prestador(cc.nnumeclapr), TO_CHAR(cc.ncrm_pres),
             cc.cconspres || ' ' || f.cufcrpres, cc.cufcrpres, cl.nnumeespec, TO_CHAR(retorna_nome_especialidade(cl.nnumeespec)),
             (SELECT t.cdesctlogr FROM hsstlogr t WHERE t.nnumetlogr = f.nnumetlogr),
             f.cendepres, f.cnendpres, f.ccomppres, f.cbairpres, f.ccidapres, f.cestapres,
             icf_fone_pessoa(f.nnumepess), cc.cnomepres
         FROM solus.finpres f
                  JOIN BaseRede b ON b.nnumepres = f.nnumepres
                  JOIN hsscclin cl ON cl.nhosppres = f.nnumepres
                  JOIN solus.finpres cc  ON cl.nnumepres = cc.nnumepres
                  JOIN hssespre es ON (es.nnumeespec = cl.nnumeespec AND es.nnumepres = f.nnumepres)
         WHERE f.cpesspres = 'J' AND f.cgruppres <> 'E'
           AND cl.cstatcclin = 'A' AND cl.cpublcclin = 'S' AND es.cpublespre = 'S'
           AND (b.espec_rede IS NULL OR b.espec_rede = cl.nnumeespec)

         UNION ALL

         ---- BLOCO 3: Corpo Clínico Empresa Médica
         SELECT
             retorna_nome_grupo_prestador(cc.cgruppres), cc.cgruppres, cc.nnumepres, cc.cnomepres, cc.cfantpres,
             NVL(cc.ccgc_pres, cc.ccpf_pres), cc.ccnespres, retorna_classif_prestador(cc.nnumeclapr), TO_CHAR(cc.ncrm_pres),
             cc.cconspres || ' ' || f.cufcrpres, cc.cufcrpres, cl.nnumeespec, TO_CHAR(retorna_nome_especialidade(cl.nnumeespec)),
             (SELECT t.cdesctlogr FROM hsstlogr t WHERE t.nnumetlogr = f.nnumetlogr),
             cc.cendepres, cc.cnendpres, cc.ccomppres, cc.cbairpres, cc.ccidapres, cc.cestapres,
             icf_fone_pessoa(cc.nnumepess), cc.cnomepres
         FROM solus.finpres f
                  JOIN hsscclin cl ON cl.nhosppres = f.nnumepres
                  JOIN solus.finpres cc  ON cl.nnumepres = cc.nnumepres
                  JOIN BaseRede b ON b.nnumepres = cc.nnumepres
                  JOIN hssespre es ON (es.nnumeespec = cl.nnumeespec AND es.nnumepres = cc.nnumepres)
         WHERE f.cpesspres = 'J' AND f.cgruppres = 'E'
           AND cl.cstatcclin = 'A' AND cl.cpublcclin = 'S' AND es.cpublespre = 'S'
           AND (b.espec_rede IS NULL OR b.espec_rede = cl.nnumeespec)

         UNION ALL

         ---- BLOCO 4: Locais de Atendimento
         SELECT
             retorna_nome_grupo_prestador(f.cgruppres), f.cgruppres, f.nnumepres, f.cfantpres, f.cfantpres,
             NVL(f.ccgc_pres, f.ccpf_pres), f.ccnespres, retorna_classif_prestador(f.nnumeclapr), '', '', '',
             es.nnumeespec, TO_CHAR(retorna_nome_especialidade(es.nnumeespec)),
             (SELECT t.cdesctlogr FROM hsstlogr t WHERE t.nnumetlogr = f.nnumetlogr),
             f.cendepres, f.cnendpres, f.ccomppres, f.cbairpres, f.ccidapres, f.cestapres,
             icf_fone_pessoa(f.nnumepess), cc_lin.cnomepres
         FROM solus.finpres f
                  JOIN BaseRede b ON b.nnumepres = f.nnumepres
                  JOIN hssespre es ON es.nnumepres = f.nnumepres
                  LEFT JOIN hsscclin cl_lin ON cl_lin.nhosppres = f.nnumepres AND cl_lin.cpublcclin = 'S' AND cl_lin.cstatcclin = 'A'
                  LEFT JOIN solus.finpres cc_lin  ON cl_lin.nnumepres = cc_lin.nnumepres
         WHERE f.cpesspres = 'J' AND es.cpublespre = 'S'
           AND (b.espec_rede IS NULL OR b.espec_rede = es.nnumeespec)
     ) v
WHERE v.id_prestador = :prestador
  AND v.idgrupo = :grupo


--FILTROS

--GRUPO
select cvalodomin,cdispdomin
from hssdomin
where ctipodomin= 'GRUPO_PRESTADOR'
  and cstatdomin='A'
order by 2

--PLANO
SELECT P.NNUMEPLAN, P.CCODIPLAN
FROM HSSPLAN P ORDER BY 2

--REGISTRO
SELECT P.NNUMEPLAN, P.NRGMSPLAN
FROM HSSPLAN P WHERE P.NRGMSPLAN IS NOT NULL ORDER BY 2

--REDE
SELECT distinct  P.NNUMEREDEA, P.CNOMEREDEA
FROM HSSREDEA P, HSSPREDE PR
WHERE P.NNUMEREDEA=PR.NNUMEREDEA
  AND P.CSITUREDEA='A'
  and P.CPRWEREDEA='A'
ORDER BY 2

--PRESTADOR
select distinct nnumepres,cnomepres
from finpres