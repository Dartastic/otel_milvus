// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_milvus/otel_milvus.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_milvus-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('search records CLIENT span', () async {
    await tracedMilvusSearch<String>(
      collection: 'docs',
      topK: 10,
      metricType: 'COSINE',
      indexType: 'HNSW',
      invoke: () async => const MilvusSearchResult(
        value: 'hits',
        resultCount: 10,
      ),
    );
    final a = attrsOf(spans.findSpanByName('milvus search docs')!);
    expect(a['db.system'], 'milvus');
    expect(a['milvus.metric_type'], 'COSINE');
    expect(a['milvus.index_type'], 'HNSW');
    expect(a['vector_db.search.top_k'], 10);
    expect(a['vector_db.search.result_count'], 10);
  });

  test('insert records CLIENT span', () async {
    await tracedMilvusInsert<String>(
      operation: 'insert',
      collection: 'docs',
      entityCount: 50,
      invoke: () async => 'ok',
    );
    final a = attrsOf(spans.findSpanByName('milvus insert docs')!);
    expect(a['milvus.entity_count'], 50);
  });

  test('suppression skips spans', () async {
    await runWithoutMilvusInstrumentationAsync(() async {
      await tracedMilvusSearch<String>(
        collection: 'c',
        invoke: () async => const MilvusSearchResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('milvus '), isEmpty);
  });
}
