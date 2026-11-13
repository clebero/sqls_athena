SELECT DISTINCT
       (SELECT CASE
                 WHEN UPPER(cnomeconf) LIKE '%NORDESTE%' THEN 'HUMANA NE'
                 WHEN UPPER(cnomeconf) LIKE '%SUL%' THEN 'HUMANA SUL'
                 WHEN UPPER(cnomeconf) LIKE '%SAMP%' THEN 'HUMANA SE'
          END operadora
        FROM hssconf 
       WHERE ROWNUM = 1)                             AS OPERADORA,
       DECODE(pr.cpwebprede,'S','Sim','N','Não')     AS PUBLICA_REDE,
       f.ccodipres                                   AS CODIGO_PRESTADOR,
       f.cpesspres                                   AS NATUREZA,
       NVL(f.ccgc_pres, f.ccpf_pres)                 AS CNPJ_CPF,
       f.cnomepres                                   AS RAZAO_SOCIAL,
       retorna_situacao_prestador(f.nnumepres)       AS SITUACAO,
       retorna_nome_grupo_prestador(f.cgruppres)     AS GRUPO,
       cp.cdescclapr                                 AS CLASSIFICACAO,
       retorna_nome_prestador(retornaempresamedicaprestador(f.nnumepres, SYSDATE)) AS EMPRESA_MEDICA,

       (SELECT SUM(l.nvalolote)
          FROM hsslote l
         WHERE l.nnumepres = f.nnumepres
           AND l.csitulote = 'F'
           AND l.dcomplote >= TRUNC(FIRST_DAY(ADD_MONTHS(SYSDATE, -6)))
       ) AS APRESENTADO_ULTIMOS6M,

       (SELECT COUNT(1)
          FROM hssguia gu
         WHERE NVL(gu.cstatguia,'L') = 'L'
           AND gu.nnumepres = f.nnumepres
           AND gu.demisguia >= TRUNC(FIRST_DAY(ADD_MONTHS(SYSDATE, -6)))
       ) AS QTD_GUIAS_EXECUTANTE6M,

       (SELECT COUNT(1)
          FROM hssguia gu
         WHERE NVL(gu.cstatguia,'L') = 'L'
           AND gu.nlocapres = f.nnumepres
           AND gu.demisguia >= TRUNC(FIRST_DAY(ADD_MONTHS(SYSDATE, -6)))
       ) AS QTD_GUIAS_LOCALATEND6M,

       DECODE(en.ctipoendp,'A','Atendimento','D','Administrativo','R','Residencial','F','Faturamento',
                           'C','Comercial','P','Correspondência','N','Nota fiscal','M','Atendimento domiciliar')
         AS TIPO_ENDERECO,

       fun_retornaDescricaoDominio('TIPO_TELEFONE_PESSOA', fo.ctipofonp) AS TIPO_TELEFONE,
       en.ccidaendp                                  AS CIDADE,
       en.cestaendp                                  AS ESTADO,
       e.cnomeespec                                  AS ESPECIALIDADES,
       ep.cpublespre                                 AS PUBLICA,

       co.cod_corpo_clinico,
       co.id_corpo_clinico,
       co.natureza_corpo_clinico,
       co.cnpj_cpf_corpo_clinico,
       co.nome_corpo_clinico,
       co.situacao_corpo_clinico,
       co.grupo_corpo_clinico,
       co.classificação_corpo_clinico,
       co.cidade_corpo_clinico,
       co.estado_corpo_clinico,
       co.especialidade_corpo_clinico,
       co.publica_corpo_clinico,
       co.status_corpo_clinico,
       co.tipo_telefone_cc,

       DECODE(co.tipo_endereco_cc,'A','Atendimento','D','Administrativo','R','Residencial','F','Faturamento',
                                 'C','Comercial','P','Correspondência','N','Nota fiscal','M','Atendimento domiciliar')
         AS TIPO_ENDERECO_CC,

       (SELECT COUNT(1)
          FROM hssguia gu
         WHERE NVL(gu.cstatguia,'L') = 'L'
           AND gu.nnumepres = id_corpo_clinico
           AND gu.demisguia >= TRUNC(FIRST_DAY(ADD_MONTHS(SYSDATE, -6)))
       ) AS QTD_GUIAS_EXECUTANTE6M_CC,

       mail.cnomeemapr                               AS EMAIL7_CONTATO,
       mail.cdescemapr                               AS EMAIL7_SETOR,
       mail.cprinemapr                               AS EMAIL7_SN_PRINC,
       mail.cemaiemapr                               AS EMAIL7

  FROM finpres f,
       hssespre ep,
       /* só colunas usadas */
       (SELECT nnumeespec, cnomeespec
          FROM hssespec
         WHERE csituespec = 'A') e,

       -- Endereço do prestador principal:
       -- prioridade: tipo Atendimento ('A'); fallback: endereço principal quando não há tipo 'A'
       (SELECT nnumepess, ctipoendp, ccidaendp, cestaendp
          FROM hssendp
         WHERE ctipoendp = 'A'
           AND cstatendp = 'A'
        UNION ALL
        SELECT nnumepess, ctipoendp, ccidaendp, cestaendp
          FROM hssendp h2
         WHERE cprinendp = 'S'
           AND cstatendp = 'A'
           AND NOT EXISTS (
                 SELECT 1 FROM hssendp h3
                  WHERE h3.nnumepess = h2.nnumepess
                    AND h3.ctipoendp = 'A'
                    AND h3.cstatendp = 'A'
               )
       ) en,

       (SELECT nnumepess, ctipofonp
          FROM hssfonp
         WHERE cprinfonp = 'S'
           AND cstatfonp = 'A') fo,
       hssemapr mail,
       hssprede pr,
       hssclapr cp,

       (SELECT
               c.nhosppres                      AS id_hospital,
               cc.ccodipres                     AS cod_corpo_clinico,
               cc.cpesspres                     AS natureza_corpo_clinico,
               cc.nnumepres                     AS id_corpo_clinico,
               NVL(cc.ccpf_pres, cc.ccgc_pres)  AS cnpj_cpf_corpo_clinico,
               cc.cconspres                     AS conselho_corpo_clinico,
               cc.ncrm_pres                     AS nr_conselho_corpo_clinico,
               cc.cufcrpres                     AS uf_crm_corpo_clinico,
               cc.cnomepres                     AS nome_corpo_clinico,
               cc.cfantpres                     AS fantasia_corpo_clinico,
               retorna_situacao_prestador(cc.nnumepres)          AS situacao_corpo_clinico,
               retorna_nome_grupo_prestador(cc.cgruppres)        AS grupo_corpo_clinico,
               cp.cdescclapr                    AS classificação_corpo_clinico,
               en.ccidaendp                     AS cidade_corpo_clinico,
               en.cestaendp                     AS estado_corpo_clinico,
               (SELECT t.cdesctlogr
                  FROM hsstlogr t
                 WHERE t.nnumetlogr = en.nnumetlogr)             AS logradouro_corpo_clinico,
               en.cendeendp                     AS endereço_corpo_clinico,
               en.cnumeendp                     AS número_corpo_clinico,
               en.cbairendp                     AS bairro_corpo_clinico,
               en.ccompendp                     AS complemento_corpo_clinico,
               en.ctipoendp                     AS tipo_endereco_cc,
               fo.cddd_fonp || ' ' || fo.cfonefonp               AS fone_corpo_clinico,
               fun_retornaDescricaoDominio('TIPO_TELEFONE_PESSOA', fo.ctipofonp) AS tipo_telefone_cc,
               e.nnumeespec                     AS id_espec_corpo_clinico,
               e.cnomeespec                     AS especialidade_corpo_clinico,
               ep.cpublespre                    AS publica_corpo_clinico,
               c.cstatcclin                     AS status_corpo_clinico
          FROM
               /* só colunas usadas nesta subquery */
               (SELECT nnumeespec, cnomeespec FROM hssespec) e,
               (SELECT nnumepres, nnumeespec, cpublespre FROM hssespre) ep,
               (SELECT nhosppres, nnumepres, NVL(cstatcclin,'I') cstatcclin FROM hsscclin) c,
               (SELECT nnumepres, ccodipres, cpesspres, ccpf_pres, ccgc_pres,
                       cconspres, ncrm_pres, cufcrpres, cnomepres, cfantpres,
                       cgruppres, nnumeclapr, nnumepess
                  FROM finpres) cc,
               (SELECT nnumeclapr, cdescclapr FROM hssclapr) cp,

               -- Endereço do corpo clínico:
               -- mesma lógica: prioridade tipo 'A'; fallback principal
               (SELECT nnumepess, nnumetlogr, ccidaendp, cestaendp,
                       cendeendp, cnumeendp, cbairendp, ccompendp, ctipoendp
                  FROM hssendp
                 WHERE ctipoendp = 'A'
                   AND cstatendp = 'A'
                UNION ALL
                SELECT nnumepess, nnumetlogr, ccidaendp, cestaendp,
                       cendeendp, cnumeendp, cbairendp, ccompendp, ctipoendp
                  FROM hssendp h2
                 WHERE cprinendp = 'S'
                   AND cstatendp = 'A'
                   AND NOT EXISTS (
                         SELECT 1 FROM hssendp h3
                          WHERE h3.nnumepess = h2.nnumepess
                            AND h3.ctipoendp = 'A'
                            AND h3.cstatendp = 'A'
                       )
               ) en,

               (SELECT nnumepess, cddd_fonp, cfonefonp, ctipofonp
                  FROM hssfonp
                 WHERE cprinfonp = 'S'
                   AND cstatfonp = 'A') fo
         WHERE ep.nnumepres = c.nnumepres
           AND e.nnumeespec = ep.nnumeespec
           AND c.nnumepres = cc.nnumepres
           AND NVL(c.cstatcclin,'I') = 'A'
           AND en.nnumepess(+) = cc.nnumepess
           AND fo.nnumepess(+) = cc.nnumepess
           AND cp.nnumeclapr(+) = cc.nnumeclapr
           AND c.nhosppres IN (
                 SELECT pp.nnumepres
                   FROM hssredea rr,
                        hssprede pp,
                        finpres f
                  WHERE pp.nnumeredea = rr.nnumeredea
                    AND f.nnumepres  = pp.nnumepres
                    AND f.cpesspres  = 'J')
       ) co

 WHERE ep.nnumeespec = e.nnumeespec(+)
   AND ep.nnumepres(+) = f.nnumepres
   AND en.nnumepess(+) = f.nnumepess
   AND fo.nnumepess(+) = f.nnumepess
   AND pr.nnumepres    = f.nnumepres
   AND cp.nnumeclapr(+)= f.nnumeclapr
   AND co.id_hospital(+)= f.nnumepres
   AND mail.nnumepres(+)= f.nnumepres
   AND pr.dfinaprede IS NULL
   AND (f.cgruppres) =  :GRUPO 
 ORDER BY f.ccodipres, co.id_corpo_clinico


--FILTRO
--GRUPO

select d.cvalodomin,d.cdispdomin
 from hssdomin d
 where ctipodomin = 'GRUPO_PRESTADOR'
ORDER BY 2