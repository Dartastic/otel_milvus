// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_milvus/otel_milvus.dart';

/// Traces Milvus calls with OpenTelemetry.
///
/// `otel_milvus` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Milvus call in
/// [tracedMilvusSearch]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'milvus-example');

  // Wraps a Milvus search in a CLIENT span.
  final milvusSearchId = await tracedMilvusSearch<String>(
    collection: 'orders',
    topK: 1,
    metricType: 'standard',
    indexType: 'products',
    invoke: () async {
      // Make the Milvus call here, then report what it returned.
      const id = 'milvus_8f3a2c';
      return const MilvusSearchResult(value: id, resultCount: 3);
    },
  );
  OTelLog.info('tracedMilvusSearch returned $milvusSearchId');

  // Wraps a Milvus insert/delete/upsert in a CLIENT span.
  final milvusInsertId = await tracedMilvusInsert<String>(
    operation: 'create',
    collection: 'orders',
    entityCount: 3,
    invoke: () async {
      // Make the Milvus call here, then report what it returned.
      return 'milvus_8f3a2c';
    },
  );
  OTelLog.info('tracedMilvusInsert create returned $milvusInsertId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutMilvusInstrumentationAsync.
  await runWithoutMilvusInstrumentationAsync(
    () => tracedMilvusSearch<String>(
      collection: 'orders',
      topK: 1,
      metricType: 'standard',
      indexType: 'products',
      invoke: () async {
        const id = 'milvus_8f3a2c';
        return const MilvusSearchResult(value: id, resultCount: 3);
      },
    ),
  );

  await OTel.shutdown();
}
