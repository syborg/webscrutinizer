# Dades per scrutinitzar la Generalitat de Catalunya https://contractaciopublica.gencat.cat/ecofin_pscp/...

GENCAT_PAGES = {
  # Futures licitacions que ja estan una mica passades ... Em sembla que ja no esta mantinguda aquesta seccio
  :ALERTES_FUTURES=> "https://contractaciopublica.gencat.cat/ecofin_pscp/AppJava/search.pscp?reqCode=searchCtn&set-locale=ca_ES",
  # Anuncis Previs: Futures licitacions que sembla que estan una mica mes actualitzades, tot i que algunes son molt velles
  :ANUNC_PREV => "https://contractaciopublica.gencat.cat/ecofin_pscp/AppJava/search.pscp?reqCode=searchPin&advancedSearch=false",
  # Anuncis de Licitacions en curs: Licitacions que es poden concursar i encara no ha arribat la data de presentacio
  :ANUNC_LICIT => "https://contractaciopublica.gencat.cat/ecofin_pscp/AppJava/search.pscp?reqCode=searchCn&advancedSearch=false",
  # Adjudciacions provisionals
  :ADJUD_PROV =>"https://contractaciopublica.gencat.cat/ecofin_pscp/AppJava/search.pscp?reqCode=searchPcan&advancedSearch=false&lawType=1",
  # Adjudciacions definitives
  :ADJUD_DEFI =>"https://contractaciopublica.gencat.cat/ecofin_pscp/AppJava/search.pscp?reqCode=searchDcan&advancedSearch=false&lawType=1",
  #EXEMPLES PER DEPARTAMENTS
  :ANUNC_PREV_CTTI => "https://contractaciopublica.gencat.cat/ecofin_pscp/AppJava/notice.pscp?reqCode=searchPin&idCap=11110",
  :LICIT_CTTI => "https://contractaciopublica.gencat.cat/ecofin_pscp/AppJava/notice.pscp?reqCode=searchCn&idCap=11110",
  :LICIT_ACA => "https://contractaciopublica.gencat.cat/ecofin_pscp/AppJava/notice.pscp?reqCode=searchCn&idCap=206317",
  :LICIT_DEP_TIS => "https://contractaciopublica.gencat.cat/ecofin_pscp/AppJava/notice.pscp?reqCode=searchCn&idCap=202144",
  :LICIT_ICS => "https://contractaciopublica.gencat.cat/ecofin_pscp/AppJava/notice.pscp?reqCode=searchCn&idCap=204588",
  :LICIT_GISA => "https://contractaciopublica.gencat.cat/ecofin_pscp/AppJava/notice.pscp?reqCode=searchCn&idCap=203633",
  :ADJUD_DEP_TIS => "https://contractaciopublica.gencat.cat/ecofin_pscp/AppJava/awardnotice.pscp?reqCode=searchDcan&idCap=202144&lawType=1",
  :ADJUD_IFERCAT=> "https://contractaciopublica.gencat.cat/ecofin_pscp/AppJava/awardnotice.pscp?reqCode=searchDcan&idCap=203663&lawType=1"
}
