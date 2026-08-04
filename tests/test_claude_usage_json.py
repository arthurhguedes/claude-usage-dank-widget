import time
from datetime import datetime, timezone

import pytest

from helpers import FakeWindow


def test_preco_para_modelo_conhecido(mod):
    assert mod.preco_para("claude-sonnet-4-5-20250929") == (3.00, 15.00)


def test_preco_para_fallback_modelo_desconhecido(mod):
    assert mod.preco_para("modelo-que-nao-existe") == mod.PRECO_PADRAO


def test_duracao_janela_sem_estimativa_configurada(mod):
    # seven_day_opus nao esta em WINDOW_DURATION_HOURS -> sem estimativa.
    w = FakeWindow("seven_day_opus", 10.0, 1000)
    duracao, limitado_por = mod.calcular_duracao_ritmo(w, [], time.time())
    assert (duracao, limitado_por) == (None, None)


def test_duracao_sem_resets_in_minutes(mod):
    w = FakeWindow("five_hour", 10.0, None)
    duracao, limitado_por = mod.calcular_duracao_ritmo(w, [], time.time())
    assert (duracao, limitado_por) == (None, None)


def test_duracao_media_desde_inicio_sem_historico(mod):
    # Janela de 5h, 1h decorrida (restam 240min), 20% de utilizacao.
    # Ritmo medio = 20%/h -> faltam 80% -> 4h ate o teto == 4h de restante,
    # empate vai para "reset" (so e "cap" se for estritamente mais rapido).
    now = time.time()
    w = FakeWindow("five_hour", 20.0, 240)
    duracao, limitado_por = mod.calcular_duracao_ritmo(w, [], now)
    assert limitado_por == "reset"
    assert duracao == pytest.approx(4.0, abs=0.01)


def test_duracao_bate_no_teto_antes_do_reset(mod):
    now = time.time()
    w = FakeWindow("five_hour", 80.0, 240)  # 1h decorrida, 80% de uso
    duracao, limitado_por = mod.calcular_duracao_ritmo(w, [], now)
    # ritmo=80%/h; faltam 20% -> 0.25h ate o teto, bem menor que as 4h de reset
    assert limitado_por == "cap"
    assert duracao == pytest.approx(0.25, abs=0.01)


def test_duracao_usa_ritmo_recente_quando_ha_historico_suficiente(mod):
    now = time.time()
    # Media desde a abertura da janela sugeriria ritmo baixo, mas nos
    # ultimos 20min o consumo disparou -- a estimativa deve refletir isso.
    samples = [
        [now - 20 * 60, 10.0],
        [now - 10 * 60, 25.0],
        [now, 40.0],
    ]
    w = FakeWindow("five_hour", 40.0, 60)  # so falta 1h pro reset
    duracao, limitado_por = mod.calcular_duracao_ritmo(w, samples, now)
    # ritmo recente = (40-10) / (20/60)h = 90%/h; faltam 60% -> ~0.667h
    assert limitado_por == "cap"
    assert duracao == pytest.approx(0.667, abs=0.01)


def test_duracao_ignora_historico_curto_demais(mod):
    now = time.time()
    # Span de so 2min (minimo exigido p/ five_hour e 8min) -> deve cair
    # para a media desde o inicio da janela, nao para o ritmo recente.
    samples = [[now - 2 * 60, 15.0], [now, 20.0]]
    w = FakeWindow("five_hour", 20.0, 240)
    duracao, limitado_por = mod.calcular_duracao_ritmo(w, samples, now)
    assert limitado_por == "reset"
    assert duracao == pytest.approx(4.0, abs=0.01)


def test_duracao_ja_no_teto(mod):
    w = FakeWindow("five_hour", 100.0, 30)
    duracao, limitado_por = mod.calcular_duracao_ritmo(w, [], time.time())
    assert limitado_por == "cap"
    assert duracao == pytest.approx(0.0, abs=0.001)


def test_duracao_robusta_a_relogio_do_sistema_voltando(mod):
    # Amostra com timestamp no "futuro" em relacao a agora (ex.: ajuste de
    # NTP) nao pode gerar ritmo negativo nem travar -- deve cair pra media.
    now = time.time()
    samples = [[now + 5 * 60, 50.0], [now, 20.0]]
    w = FakeWindow("five_hour", 20.0, 240)
    duracao, limitado_por = mod.calcular_duracao_ritmo(w, samples, now)
    assert limitado_por == "reset"
    assert duracao == pytest.approx(4.0, abs=0.01)


def test_atualizar_historico_poda_amostras_antigas(mod):
    now = time.time()
    history = {
        "five_hour": {
            "resets_at": None,
            "samples": [[now - 60 * 60, 5.0], [now - 10 * 60, 8.0]],
        }
    }
    w = FakeWindow("five_hour", 10.0, 240, resets_at=None)
    samples = mod._atualizar_historico(history, w, now)
    assert [now - 60 * 60, 5.0] not in samples
    assert samples[-1] == [now, 10.0]


def test_atualizar_historico_reseta_ao_trocar_de_janela(mod):
    now = time.time()
    old_reset = datetime(2026, 1, 1, tzinfo=timezone.utc)
    new_reset = datetime(2026, 1, 8, tzinfo=timezone.utc)
    history = {
        "five_hour": {"resets_at": old_reset.isoformat(), "samples": [[now - 60, 50.0]]}
    }
    w = FakeWindow("five_hour", 5.0, 240, resets_at=new_reset)
    samples = mod._atualizar_historico(history, w, now)
    assert samples == [[now, 5.0]]


def test_atualizar_historico_ignora_jitter_de_subsegundo_no_resets_at(mod):
    # Bug real observado contra a API: resets_at muda por ~800ms entre
    # chamadas dentro da mesma janela (jitter do servidor). Isso nao pode
    # ser tratado como rollover de janela, senao o historico nunca
    # acumula amostras.
    now = time.time()
    reset_a = datetime(2026, 8, 4, 5, 40, 0, 69318, tzinfo=timezone.utc)
    reset_b = datetime(2026, 8, 4, 5, 40, 0, 869335, tzinfo=timezone.utc)

    history = {}
    w1 = FakeWindow("five_hour", 40.0, 240, resets_at=reset_a)
    mod._atualizar_historico(history, w1, now)

    w2 = FakeWindow("five_hour", 42.0, 239, resets_at=reset_b)
    samples = mod._atualizar_historico(history, w2, now + 60)

    assert samples == [[now, 40.0], [now + 60, 42.0]]


def test_atualizar_historico_limita_tamanho(mod):
    now = time.time()
    many = [[now - i, 1.0] for i in range(600)]
    history = {"five_hour": {"resets_at": None, "samples": many}}
    w = FakeWindow("five_hour", 1.0, 240, resets_at=None)
    samples = mod._atualizar_historico(history, w, now)
    assert len(samples) == 500


def test_history_save_load_roundtrip(mod, tmp_path, monkeypatch):
    monkeypatch.setattr(mod, "get_claude_dir", lambda: tmp_path)
    data = {"five_hour": {"resets_at": None, "samples": [[1.0, 2.0]]}}
    mod._save_history(data)
    assert mod._load_history() == data
    assert (tmp_path / "usage-window-history.json").exists()
    assert list(tmp_path.glob(".usage-window-history-*.tmp")) == []


def test_load_history_arquivo_corrompido_nao_quebra(mod, tmp_path, monkeypatch):
    monkeypatch.setattr(mod, "get_claude_dir", lambda: tmp_path)
    (tmp_path / "usage-window-history.json").write_text("{isso nao e json valido")
    assert mod._load_history() == {}


def test_plan_price_usd_tem_fallback_para_plano_invalido(mod):
    assert mod.PLAN_PRECO_USD.get("plano-inventado", mod.PLAN_PRECO_USD["pro"]) == 20
