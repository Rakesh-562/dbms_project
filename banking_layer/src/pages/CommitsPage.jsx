import { useState } from 'react';
import { useApi } from '../hooks';
import { getVcsLog, getCommitDetail } from '../api';
import { PageHeader, Card, DataTable, Badge, Spinner, ErrorBox } from '../components/UI';
import { GitCommitHorizontal } from 'lucide-react';

export default function CommitsPage() {
  const [selected, setSelected] = useState(null);
  const log = useApi(() => getVcsLog(null, 100));
  const detail = useApi(() => selected ? getCommitDetail(selected) : Promise.resolve(null), [selected]);

  if (log.loading) return <Spinner />;
  if (log.error) return <ErrorBox message={log.error} onRetry={log.refetch} />;

  return (
    <>
      <PageHeader title="Commit History" subtitle="Full commit log across all branches" />

      <div className="grid lg:grid-cols-5 gap-6">
        <Card className="lg:col-span-3 p-0">
          <DataTable
            columns={[
              { key: 'commit_id', label: 'ID', render: (r) => (
                <button
                  onClick={() => setSelected(r.commit_id)}
                  className={`font-mono font-bold px-2 py-0.5 rounded ${
                    selected === r.commit_id ? 'bg-indigo-100 text-indigo-700' : 'text-indigo-600 hover:underline'
                  }`}
                >
                  #{r.commit_id}
                </button>
              )},
              { key: 'branch', label: 'Branch', render: (r) => <Badge variant="indigo">{r.branch}</Badge> },
              { key: 'hash', label: 'Hash', render: (r) => <span className="font-mono text-xs text-gray-400">{r.hash?.slice(0, 8)}</span> },
              { key: 'message', label: 'Message' },
              { key: 'author', label: 'Author' },
              { key: 'committed_at', label: 'Date', render: (r) => new Date(r.committed_at).toLocaleString() },
            ]}
            rows={log.data}
          />
        </Card>

        <Card className="lg:col-span-2 p-5">
          <h3 className="font-semibold text-gray-900 mb-3 flex items-center gap-2">
            <GitCommitHorizontal size={18} />
            Commit Details
          </h3>
          {!selected && <p className="text-gray-400 text-sm">Click a commit to see details</p>}
          {selected && detail.loading && <Spinner />}
          {selected && detail.error && <ErrorBox message={detail.error} />}
          {selected && detail.data && (
            <div className="space-y-2 text-sm max-h-[60vh] overflow-y-auto">
              {/* Metadata rows */}
              {detail.data.filter(r => r.field !== 'Changes').map((row, i) => (
                <div key={`m${i}`} className="flex gap-2 text-sm">
                  <span className="font-medium text-gray-500 min-w-[80px]">{row.field}</span>
                  <span className="text-gray-900">{row.value}</span>
                </div>
              ))}
              {/* Change rows */}
              {detail.data.filter(r => r.field === 'Changes').length > 0 && (
                <div className="pt-2 border-t border-gray-100">
                  <h4 className="text-xs font-semibold text-gray-500 uppercase mb-2">Changes</h4>
                  {detail.data.filter(r => r.field === 'Changes').map((row, i) => {
                    const m = row.value.match(/^(\w+):\s+(INSERT|UPDATE|DELETE)\s+(.+)/);
                    const table = m ? m[1] : '?';
                    const op = m ? m[2] : '?';
                    const pk = m ? m[3] : row.value;
                    return (
                      <div key={`c${i}`} className="bg-gray-50 rounded-lg p-2 border border-gray-100 mb-1 flex items-center gap-2">
                        <Badge variant={op === 'INSERT' ? 'green' : op === 'DELETE' ? 'red' : 'amber'}>{op}</Badge>
                        <span className="text-gray-600 font-medium">{table}</span>
                        <span className="text-gray-400 text-xs">PK {pk}</span>
                      </div>
                    );
                  })}
                </div>
              )}
              {detail.data.length === 0 && <p className="text-gray-400">No changes in this commit</p>}
            </div>
          )}
        </Card>
      </div>
    </>
  );
}
