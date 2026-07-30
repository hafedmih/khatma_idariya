<?php
// ═══════════════════════════════════════════════
//  عدّاد بسيط: المتصلون الآن + إجمالي الزيارات
//  يخزّن البيانات محلياً في counter.json (لا طرف ثالث)
// ═══════════════════════════════════════════════
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

$dataFile      = __DIR__ . '/counter.json';
$ONLINE_WINDOW = 120; // ثانية: يُعتبر المستخدم "متصلاً" إن ظهر خلالها
$now           = time();

$vid        = isset($_GET['vid']) ? preg_replace('/[^A-Za-z0-9]/', '', substr($_GET['vid'], 0, 40)) : '';
$isNewVisit = isset($_GET['visit']) && $_GET['visit'] === '1';

$fp = @fopen($dataFile, 'c+');
if ($fp === false) { echo json_encode(['online' => 0, 'total' => 0]); exit; }

flock($fp, LOCK_EX);
$raw  = stream_get_contents($fp);
$data = json_decode($raw, true);
if (!is_array($data)) $data = ['total' => 0, 'online' => []];
if (!isset($data['online']) || !is_array($data['online'])) $data['online'] = [];
if (!isset($data['total'])) $data['total'] = 0;

if ($isNewVisit) $data['total']++;
if ($vid !== '') $data['online'][$vid] = $now;

// إزالة غير النشطين
foreach ($data['online'] as $k => $t) {
  if ($now - $t > $ONLINE_WINDOW) unset($data['online'][$k]);
}

ftruncate($fp, 0);
rewind($fp);
fwrite($fp, json_encode($data));
fflush($fp);
flock($fp, LOCK_UN);
fclose($fp);

echo json_encode(['online' => count($data['online']), 'total' => (int)$data['total']]);
