// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_milvus_suppression.dart';

const _tracerName = 'dartastic_otel_libs_milvus';
const _systemValue = 'milvus';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

/// Pair returned from `tracedMilvusSearch` callback.
class MilvusSearchResult<T> {
  const MilvusSearchResult({required this.value, this.resultCount});
  final T value;
  final int? resultCount;
}

/// Wraps a Milvus `search` in a CLIENT span.
Future<T> tracedMilvusSearch<T>({
  required String collection,
  required Future<MilvusSearchResult<T>> Function() invoke,
  int? topK,
  String? metricType,
  String? indexType,
}) async {
  if (milvusInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'db.system': _systemValue,
    'db.operation': 'search',
    'db.collection.name': collection,
    'milvus.collection': collection,
  };
  if (topK != null) m['vector_db.search.top_k'] = topK;
  if (metricType != null) m['milvus.metric_type'] = metricType;
  if (indexType != null) m['milvus.index_type'] = indexType;

  final span = _tracer().startSpan(
    'milvus search $collection',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.resultCount != null) {
      span.addAttributes(OTel.attributes([
        OTel.attributeInt('vector_db.search.result_count', r.resultCount!),
      ]));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}

/// Wraps a Milvus insert/delete/upsert in a CLIENT span.
Future<T> tracedMilvusInsert<T>({
  required String operation,
  required String collection,
  required Future<T> Function() invoke,
  int? entityCount,
}) async {
  if (milvusInstrumentationSuppressed()) {
    return invoke();
  }
  final m = <String, Object>{
    'db.system': _systemValue,
    'db.operation': operation,
    'db.collection.name': collection,
    'milvus.collection': collection,
  };
  if (entityCount != null) m['milvus.entity_count'] = entityCount;

  final span = _tracer().startSpan(
    'milvus $operation $collection',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    return await invoke();
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
