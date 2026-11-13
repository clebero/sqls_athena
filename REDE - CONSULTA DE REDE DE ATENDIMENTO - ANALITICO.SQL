SELECT DISTINCT
    (SELECT CASE
                WHEN UPPER(cnomeconf) LIKE '%NORDESTE%' THEN 'HUMANA NE'
                WHEN UPPER(cnomeconf) LIKE '%SUL%' THEN 'HUMANA SUL'
                WHEN UPPER(cnomeconf) LIKE '%SAMP%' THEN 'SAMP SBS'
                END operadora
     FROM hssconf
     WHERE ROWNUM = 1) AS OPERADORA,
    ra.cnomeredea                              AS rede_atendimento,
    ra.nnumeredea                              AS id_rede,
    retorna_nome_especialidade(pr.nnumeespec)  AS especialidade_rede,
    DECODE(pr.cnatuprede,'T','Ambulatorial e Internação','A','Ambulatorial','I','Internação') AS natureza_atend_rede,
    DECODE(pr.curgeprede,'T','Eletivo e Urgente','E','Eletivo','U','Urgente') AS regime_atend_rede,
    DECODE(pr.cpwebprede,'S','Sim','N','Não')  AS publica_rede,

    f.ccodipres                                AS codigo_prestador,
    f.nnumepres                                AS idprestador,
    f.cpesspres                                AS natureza,
    NVL(f.ccgc_pres,f.ccpf_pres)               AS cnpj_cpf,
    f.cnomepres                                AS razao_social,
    f.cfantpres                                AS nome_fantasia,
    retorna_situacao_prestador(f.nnumepres)    AS situacao,
    retorna_nome_grupo_prestador(f.cgruppres)  AS grupo,
    cp.cdescclapr                              AS classificacao,
    retorna_nome_prestador(retornaempresamedicaprestador(f.nnumepres,SYSDATE)) AS empresa_medica,

    vl.apresentado_ultimos12m,
    upg.ultimo_pgt,

    DECODE(en.ctipoendp,'A','Atendimento','D','Administrativo','R','Residencial','F','Faturamento','C','Comercial','P','Correspondência','N','Nota fiscal','M','Atendimento domiciliar') AS tipo_endereco,
    en.ccidaendp AS cidade,
    en.cestaendp AS estado,
    (SELECT t.cdesctlogr FROM hsstlogr t WHERE t.nnumetlogr = en.nnumetlogr) AS logradouro,
    en.cendeendp AS endereco,
    en.cnumeendp AS numero,
    en.cbairendp AS bairro,
    en.ccompendp AS complemento,

    fone.ddd || ' ' || fone.numero             AS fone,
    email_pessoa.email                         AS email,

    e.cnomeespec                               AS especialidades,
    ep.cpublespre                              AS PUBLICA,

    mail.cnomeemapr                            AS email7_contato,
    mail.cdescemapr                            AS email7_setor,
    mail.cprinemapr                            AS email7_sn_princ,
    mail.cemaiemapr                            AS email7,
    DECODE(f.cfconpres,
           'P','Produção',
           'A','Assalariado',
           'C','Captação (Orçamento Global)',
           'H','Horista baseado no atendimento',
           'G','Horista baseado no cartão ponto',
           'T','Captação (Valor por vidas)'
    )                                           AS forma_contratacao,
    nvl(an.cncomusua,an.cnomeusua)             AS analista_responsavel
FROM   finpres f
           JOIN   hssprede pr   ON pr.nnumepres = f.nnumepres AND pr.dfinaprede IS NULL
           JOIN   hssredea ra   ON ra.nnumeredea = pr.nnumeredea
           LEFT  JOIN hssclapr cp  ON cp.nnumeclapr = f.nnumeclapr
           LEFT  JOIN hssespre ep  ON ep.nnumepres  = f.nnumepres
           LEFT  JOIN hssespec e   ON e.nnumeespec  = ep.nnumeespec AND e.csituespec = 'A'
           LEFT JOIN segusua an ON an.nnumeusua = f.nancmusua
           LEFT  JOIN (
    SELECT ee.nnumepess, ee.ctipoendp, ee.ccidaendp, ee.cestaendp, ee.nnumetlogr,
           ee.cendeendp, ee.cnumeendp, ee.cbairendp, ee.ccompendp
    FROM   hssendp ee
    WHERE  ee.cstatendp = 'A'
      AND (ee.ctipoendp = 'A' OR ee.cprinendp = 'S')
) en ON en.nnumepess = f.nnumepess
           LEFT  JOIN (
    SELECT /*+ NO_MERGE MATERIALIZE */ h.nnumepess, MAX(h.cddd_fonp) AS ddd, MAX(h.cfonefonp) AS numero
    FROM   hssfonp h
    WHERE  h.cstatfonp = 'A' AND h.cprinfonp = 'S'
    GROUP BY h.nnumepess
) fone ON fone.nnumepess = f.nnumepess
           LEFT  JOIN (
    SELECT /*+ NO_MERGE MATERIALIZE */ em.nnumepess, MAX(em.cmailemap) AS email
    FROM   hssemap em
    WHERE  em.cstatemap='A' AND em.cprinemap='S'
    GROUP BY em.nnumepess
) email_pessoa ON email_pessoa.nnumepess = f.nnumepess
           LEFT  JOIN (
    SELECT /*+ NO_MERGE MATERIALIZE */ m.nnumepres,
                                       MAX(m.cnomeemapr) AS cnomeemapr, MAX(m.cdescemapr) AS cdescemapr,
                                       MAX(m.cprinemapr) AS cprinemapr, MAX(m.cemaiemapr) AS cemaiemapr
    FROM hssemapr m GROUP BY m.nnumepres
) mail ON mail.nnumepres = f.nnumepres
           LEFT  JOIN (
    SELECT /*+ NO_MERGE MATERIALIZE */ l.nnumepres, SUM(l.nvalolote) AS apresentado_ultimos12m
    FROM   hsslote l
    WHERE  l.csitulote='F' AND l.dcomplote >= TRUNC(FIRST_DAY(ADD_MONTHS(SYSDATE,-24)))
    GROUP BY l.nnumepres
) vl ON vl.nnumepres = f.nnumepres
           LEFT  JOIN (
    SELECT /*+ NO_MERGE MATERIALIZE */ d.crefedocu, MAX(d.dprogdocu) AS ultimo_pgt
    FROM findocu d GROUP BY d.crefedocu
) upg ON upg.crefedocu = f.cnomepres
WHERE ra.nnumeredea = :REDE
  AND retorna_nome_grupo_prestador(f.cgruppres) = :grupo
  AND f.nnumepres = :idprestador
  AND f.nnumeclapr = :classificacao
  AND en.ccidaendp = :cidade_prestador
  AND ra.nnumeredea IN (
    SELECT DISTINCT rpl.nnumeredea
    FROM hssredpl rpl JOIN hssplan pln ON pln.nnumeplan = rpl.nnumeplan
    WHERE pln.nnumeplan = :codplan
)
  AND ra.nnumeredea IN (
    SELECT DISTINCT rpl.nnumeredea
    FROM hssredpl rpl JOIN hssplan pln ON pln.nnumeplan = rpl.nnumeplan
    WHERE pln.nnumeplan = :plano
)
ORDER BY natureza_atend_rede

--FILTROS

--REDE
SELECT NNUMEREDEA, CNOMEREDEA FROM HSSREDEA ORDER BY 2

--GRUPO
select cdispdomin, cdispdomin
from hssdomin
where 1=1
  and ctipodomin='GRUPO_PRESTADOR'
order by 1

--PRESTADOR
select nnumepres,cnomepres
from finpres
order by 2

--CLASSIFICACAO

select nnumeclapr, cdescclapr
from hssclapr
order by 2

--CCODIPLAN

select distinct pl.nnumeplan,pl.ccodiplan
from hssplan pl
where 1=1
  and pl.nnumeplan in (select distinct rpl.nnumeplan
                       from hssredpl rpl
                       where rpl.nnumeplan=pl.nnumeplan
)
order by 2

--PLANO

select distinct pl.nnumeplan,pl.cdescplan
from hssplan pl
where 1=1
  and pl.nnumeplan in (select distinct rpl.nnumeplan
                       from hssredpl rpl
                       where rpl.nnumeplan=pl.nnumeplan
)
order by 2

--CIDADE PRESTADOR

select distinct cnomecidad
from hsscidad
where cnomecidad in ( select distinct e.ccidaendp from hssendp e)