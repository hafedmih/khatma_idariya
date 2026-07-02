-- ══════════════════════════════════════════════════════════════
--  1. Créer la table hizb_links
-- ══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.hizb_links (
  hizb        INTEGER      PRIMARY KEY,
  youtube     TEXT         NOT NULL DEFAULT '',
  pdf         TEXT         NOT NULL DEFAULT '',
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ── Mettre à jour updated_at automatiquement ──
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_hizb_links_updated_at
  BEFORE UPDATE ON public.hizb_links
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ══════════════════════════════════════════════════════════════
--  2. Row Level Security
-- ══════════════════════════════════════════════════════════════
ALTER TABLE public.hizb_links ENABLE ROW LEVEL SECURITY;

-- Lecture publique (app sans login)
CREATE POLICY "read_all" ON public.hizb_links
  FOR SELECT USING (true);

-- Écriture réservée aux utilisateurs connectés (admin)
CREATE POLICY "admin_write" ON public.hizb_links
  FOR ALL USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

-- ══════════════════════════════════════════════════════════════
--  3. Insérer les 60 ahzab
-- ══════════════════════════════════════════════════════════════
INSERT INTO public.hizb_links (hizb, youtube, pdf) VALUES
(1,  'https://youtu.be/hSlwpTA7RfA',          'https://drive.google.com/file/d/1R4xMIpzyK96H6reObBaBVTaA_qorQaNo/view?usp=drive_link'),
(2,  'https://www.youtube.com/watch?v=8VA8nm82UCY', 'https://drive.google.com/file/d/1Eu9qlviGF9IreLOfH36TxSYuxuuMgCDJ/view?usp=drive_link'),
(3,  'https://youtu.be/zgtXr2hZtXo',          'https://drive.google.com/file/d/1BrnSS4ByHrtHrRm61a59dEgmgXTyRcx8/view?usp=drive_link'),
(4,  'https://youtu.be/q6sKcidrD-M',          'https://drive.google.com/file/d/1L-Z9N24jrbntKZC0GMkIXpFKGFwzdYrH/view?usp=drive_link'),
(5,  'https://youtu.be/70kFGajEDDQ',          'https://drive.google.com/file/d/1NI2LkqQ7ntvkgdEliKJ39P7w_s5Mwuph/view?usp=drive_link'),
(6,  'https://youtu.be/RRLXmnheaAk',          'https://drive.google.com/file/d/13sli7Saj3HiTVUfg2zKgGNr-rAt0Lu8w/view?usp=drive_link'),
(7,  'https://youtu.be/q8v4OYJ_iRc',          'https://drive.google.com/file/d/1NgDmSGgYLGVtWVl3ep9Q2xJ8DGa-ueHH/view?usp=drive_link'),
(8,  'https://youtu.be/1d4iT5r_R4k',          'https://drive.google.com/file/d/1BIBAV5P7SeDbzz7wfxEMrx82qCFRq-P_/view?usp=drive_link'),
(9,  'https://youtu.be/CZGiGsW3H1A',          'https://drive.google.com/file/d/1Qeg4SHiGV2XlcM-GaTBoJiCMapYYmXzx/view?usp=drive_link'),
(10, 'https://youtu.be/MCU3GSlXR-Y',          'https://drive.google.com/file/d/139Ww-yt1DUV2RaG6jPaKu8UwXtMhi18j/view?usp=drive_link'),
(11, 'https://youtu.be/nE1DS_C0L9k',          'https://drive.google.com/open?id=1zumWZETceEu8R1_oK9dcSupafoYDbd9W'),
(12, 'https://youtu.be/p91WWgQOoKA',          'https://drive.google.com/open?id=15H8qOpB-9WGQ4-0OKQES8HHXi4DBeASm'),
(13, 'https://youtu.be/0o74uIWyd-8',          'https://drive.google.com/open?id=1h3YMLpFWpefaiQkmisB93BoMhiXgVqQO'),
(14, 'https://youtu.be/0o74uIWyd-8?t=1556',   'https://drive.google.com/open?id=1TftPcTZslxXpb695H-mz43MDMY8T8W0o'),
(15, 'https://youtu.be/nD4mUSnvCA8',          'https://drive.google.com/open?id=1HmmFFr92pkYK9rusfNJG4zSRsVr9AAul'),
(16, 'https://youtu.be/tlXXSf-PzBk',          'https://drive.google.com/open?id=119sSQwr9Uas1dizfolwPOcVD6QtOmL6C'),
(17, 'https://youtu.be/UtqrgQ2RY2w',          'https://drive.google.com/open?id=152EIRsoeaE4qXQHcOAlL8u2HusYNsejP'),
(18, 'https://www.youtube.com/watch?v=wihDP6yqYgs', 'https://drive.google.com/open?id=1rcmtNuzlKnJRqu1tt6ZxZbxHQT5a0wg1'),
(19, 'https://youtu.be/mIcXCs_dOj4',          'https://drive.google.com/open?id=1SPvpf6KatfNyEDcJVZxrnBzko9UfjzB7'),
(20, 'https://youtu.be/Dwf36Mxksxk',          'https://drive.google.com/open?id=1iDbWeYDuxnj8d9E5zBMkGeUNZiGrnF0K'),
(21, 'https://youtu.be/eWAp_Y2E0Ls',          'https://drive.google.com/open?id=1GOW9mfEbuvHcqvPz9p5wK9Prq2gw3oSA'),
(22, 'https://youtu.be/a--0qIih01E?t=1490',   'https://drive.google.com/open?id=1-nr88_gUA8DgZ4T0259IXv8YslZKXeod'),
(23, 'https://youtu.be/Ccaswtvixbw',          'https://drive.google.com/open?id=1LI2iiWTa9sG724_a9scJ03fCOb-x8cOj'),
(24, 'https://youtu.be/Lir3FMDSZ98',          'https://drive.google.com/open?id=1mC8MOSBr8L4_KCM8qWCN4awl1hShboMP'),
(25, 'https://youtu.be/kkY0c-6X-y0',          'https://drive.google.com/open?id=1An_yQf-JK7K1V6K-REY7Ajpk-l6SZ4W-'),
(26, 'https://youtu.be/mRSeazYm5BE',          'https://drive.google.com/open?id=1L3Lmqw38-z6v2z9MDkxf1U4y_jUS6hal'),
(27, 'https://youtu.be/YU1BZTcxjxs',          'https://drive.google.com/open?id=1aNHGnnY7e6K0aeNpcxaCysl505McIlGl'),
(28, 'https://youtu.be/YU1BZTcxjxs?t=1622',   'https://drive.google.com/open?id=18WmYlsKXJ7pnFkMRBEWv8qY-geOHKAbr'),
(29, 'https://youtu.be/AeUx-zz-pRM',          'https://drive.google.com/open?id=1hGuglvuilw53iWvEmjPqAdB5Vs7bRfd0'),
(30, 'https://youtu.be/AeUx-zz-pRM?t=1574',   'https://drive.google.com/open?id=1WNdTgMf-IQL7dG8J8puQ4q-NSyz2cvMx'),
(31, 'https://youtu.be/EDRWK3JBD8E',          'https://drive.google.com/open?id=1Mk1_0Fk6JK-k14k3IXl0Xra9o7BYG47z'),
(32, 'https://youtu.be/JOIFnCMw-OQ',          'https://drive.google.com/open?id=1F_-n5OKhMPWmVzk7E46T-oHmw9521lzY'),
(33, 'https://youtu.be/CDYXdu-pCDU',          'https://drive.google.com/open?id=1bPJtKZg13v4FeJCPJC9OEAOSoy-nleOb'),
(34, 'https://youtu.be/CDYXdu-pCDU?t=1376',   'https://drive.google.com/open?id=19dxJYEdM7fm4zmuxJowREkIF8BCe6SIQ'),
(35, 'https://youtu.be/9iHjc95F1VU',          'https://drive.google.com/open?id=1t74K8xxTSPzzCt4tqSbeejyhLrqkY4-f'),
(36, 'https://youtu.be/4Bs8aX2eck0?t=1637',   'https://drive.google.com/open?id=1ieTcUTOfsNiI-rRrdofCSUkmLpTUvq55'),
(37, 'https://www.youtube.com/watch?v=eBaDTIga1mE', 'https://drive.google.com/open?id=1tJWm4j9stPMN4sHStAG3tgeQrEfgdWZg'),
(38, 'https://youtu.be/P0eaRpDWMkI',          'https://drive.google.com/open?id=1CdiTqmpyxqo56Xa4v_jn6CB7WZtghjUo'),
(39, 'https://youtu.be/QxupT1ntUZg',          'https://drive.google.com/open?id=1IO4qMK2yNiNsyKLYi6oRPEIDA3dC3cxs'),
(40, 'https://youtu.be/rBlv6uF-Fc4',          'https://drive.google.com/open?id=1-oiStU8UBYx_7Z0XbPY_NGqiAPFwp-nw'),
(41, 'https://youtu.be/oDv5eKQKWqo',          'https://drive.google.com/open?id=1JjGDzPoLlADf686JmIGoDAuKWpsz9fa3'),
(42, 'https://youtu.be/mvAElweeZZs?t=1660',   'https://drive.google.com/open?id=1iaL0aVeiVza9tLWFIaqGGoA4bOZtZZ3O'),
(43, 'https://youtu.be/wfie7Gf9gAc',          'https://drive.google.com/open?id=1E1uzyNO2iDncOm9oe88kK6s8krvY3ZEm'),
(44, 'https://youtu.be/fCF0VFkYtbM',          'https://drive.google.com/open?id=1F3YHptY2r2fRYuRO-RY9eqYdoxzyv92-'),
(45, 'https://youtu.be/7Zk6FjTSQ68',          'https://drive.google.com/open?id=13-TzqK1f9wjVvp64BfFUj_rErwRzFg2d'),
(46, 'https://youtu.be/SnxoMRDCI1Q?t=1210',   'https://drive.google.com/open?id=17k53exTYRkotv4UmeeYsSpEP_ZjYFRIH'),
(47, 'https://youtu.be/hI1bq5JYrtI',          'https://drive.google.com/open?id=1IpxchPh4upOjDYegoUQPqFsvpBxOirow'),
(48, 'https://youtu.be/nX02eSn_wRM',          'https://drive.google.com/open?id=1Os1WUNFWwrPLtKqmEYebgq5oo4h4fuok'),
(49, 'https://youtu.be/Cg5kRni-OpU',          'https://drive.google.com/open?id=1XnU9FckwTJ1qluODSjQ53IYPeoKB2BOL'),
(50, 'https://youtu.be/VD3dTuvI9VE',          'https://drive.google.com/open?id=1Xe6bDjWg-GkGg0Axbg7kiN1Dppgtsva5'),
(51, 'https://youtu.be/NaLZ3YFHX0k',          'https://drive.google.com/open?id=1OGXvT6EvD7k5mUyh_bHYSzR1FK1lpBzv'),
(52, 'https://youtu.be/NaLZ3YFHX0k?t=1537',   'https://drive.google.com/open?id=1_C9HI80OPG7nADi5hiDqgOEyFcjOdC5X'),
(53, 'https://youtu.be/wVBIkT9k5qw',          'https://drive.google.com/open?id=1oVC6_vY3s_Cg5zM4A9jdqfL5PJcK60xM'),
(54, 'https://youtu.be/wVBIkT9k5qw?t=1216',   'https://drive.google.com/open?id=16jh6zgDLsjGJLAe7MYgSE413JmeofWYB'),
(55, 'https://youtu.be/AGf0v4yN-oo',          'https://drive.google.com/open?id=1YKEzXwbhF0VJjXW46uA3o_zpb5a_zV-r'),
(56, 'https://youtu.be/AGf0v4yN-oo?t=1642',   'https://drive.google.com/open?id=1uQHyuCRS7CSlbOT1RWIjMKMZyhnMba3H'),
(57, 'https://youtu.be/Go8sngBM5fk',          'https://drive.google.com/open?id=1BbhjJzFHg0Jd06itYGs5FPBvSoyaj9D5'),
(58, 'https://youtu.be/Go8sngBM5fk?t=1591',   'https://drive.google.com/open?id=1RVlkriGHQ94EcsG2clMedFrFh4VbgtQa'),
(59, 'https://youtu.be/iSqfUM-pAhw',          'https://drive.google.com/open?id=12SzJIEZmKlAPoqJ2YNkKcbeiO1XsYh2r'),
(60, 'https://youtu.be/iSqfUM-pAhw?t=1341',   'https://drive.google.com/open?id=1-Q9aGOPrEE7Hpva4Fs9ucGnbwuhBYnsg')
ON CONFLICT (hizb) DO NOTHING;

-- ══════════════════════════════════════════════════════════════
--  4. جدول أوقات بداية كل صفحة لكل حزب
--     page_times: مصفوفة 7 أرقام (ثواني) للصفحات 2→8
--     الصفحة 1 دائماً = 0 (غير مخزنة)
--     مثال: (1, ARRAY[240,480,720,960,1200,1440,1680])
--     ← صفحة 2 = 240s، صفحة 3 = 480s، ...
-- ══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.hizb_page_times (
  hizb       INTEGER   PRIMARY KEY REFERENCES public.hizb_links(hizb),
  page_times INTEGER[] NOT NULL DEFAULT '{}'
);

ALTER TABLE public.hizb_page_times ENABLE ROW LEVEL SECURITY;

CREATE POLICY "read_all"    ON public.hizb_page_times FOR SELECT USING (true);
CREATE POLICY "admin_write" ON public.hizb_page_times FOR ALL
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');
