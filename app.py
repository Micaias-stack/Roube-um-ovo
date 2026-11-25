from pathlib import Path
import streamlit as st

st.set_page_config(
    page_title="Painel Script • Roube um Ovo",
    page_icon="🥚",
    layout="centered",
)

st.title("🥚 Painel de Controle • Roube um Ovo")
st.caption("Gerenciador GitHub + Streamlit para execução rápida no Delta")

# Leitura segura do arquivo script.lua na mesma pasta do repositório
lua_path = Path(__file__).parent / "script.lua"
if lua_path.exists():
    raw_lua = lua_path.read_text(encoding="utf-8")
else:
    raw_lua = '-- Erro: arquivo "script.lua" não encontrado na raiz do repositório.'
    st.error('Crie o arquivo "script.lua" na raiz do seu repositório GitHub.')

tab_loader, tab_custom = st.tabs(["⚡ Loadstring (Delta)", "🎛️ Gerador Personalizado"])

with tab_loader:
    st.subheader("Execução Direta via GitHub Raw")
    col1, col2 = st.columns(2)
    with col1:
        gh_user = st.text_input("Usuário do GitHub", value="seu-usuario")
    with col2:
        gh_repo = st.text_input("Nome do Repositório", value="roube-um-ovo")

    branch = st.text_input("Branch", value="main")

    st.markdown("**Configuração inicial antes de carregar:**")
    c1, c2 = st.columns(2)
    with c1:
        cfg_eggs = st.toggle("Auto Roubar & Entregar", value=True, key="ld_eggs")
        cfg_events = st.toggle("Auto Itens de Evento", value=True, key="ld_events")
    with c2:
        cfg_tread = st.toggle("Auto Esteira (Speed)", value=True, key="ld_tread")
        cfg_claim = st.toggle("Auto Resgatar Missões", value=True, key="ld_claim")

    cfg_speed = st.slider("Velocidade de Movimento (studs/s)", 60, 220, 135, key="ld_speed")

    raw_url = f"https://raw.githubusercontent.com/{gh_user.strip()}/{gh_repo.strip()}/{branch.strip()}/script.lua"

    loadstring_code = (
        f"_G.RoubeUmOvo_Config = {{\n"
        f"    AutoEggs = {'true' if cfg_eggs else 'false'},\n"
        f"    AutoEvents = {'true' if cfg_events else 'false'},\n"
        f"    AutoTreadmill = {'true' if cfg_tread else 'false'},\n"
        f"    AutoClaim = {'true' if cfg_claim else 'false'},\n"
        f"    MoveSpeed = {cfg_speed}\n"
        f"}}\n"
        f'loadstring(game:HttpGet("{raw_url}"))()'
    )

    st.markdown("**Copie e cole no Delta:**")
    st.code(loadstring_code, language="lua")

with tab_custom:
    st.subheader("Código Completo Autônomo (Sem Link Externo)")
    st.write("Use esta aba se quiser colar o script inteiro diretamente no executor sem depender de internet para baixar o arquivo.")
    st.code(raw_lua, language="lua")
