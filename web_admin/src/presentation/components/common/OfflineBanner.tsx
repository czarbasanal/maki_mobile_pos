import { useEffect } from 'react';
import { CloudOff } from 'lucide-react';
import { useUiStore } from '@/presentation/stores/uiStore';

export function OfflineBanner() {
  const offline = useUiStore((s) => s.offline);
  const setOffline = useUiStore((s) => s.setOffline);

  useEffect(() => {
    setOffline(!navigator.onLine);
    const onOnline = () => setOffline(false);
    const onOffline = () => setOffline(true);
    window.addEventListener('online', onOnline);
    window.addEventListener('offline', onOffline);
    return () => {
      window.removeEventListener('online', onOnline);
      window.removeEventListener('offline', onOffline);
    };
  }, [setOffline]);

  if (!offline) return null;

  return (
    <div className="flex items-center gap-tk-sm bg-light-text-secondary px-tk-md py-tk-sm text-white">
      <CloudOff className="h-4 w-4" />
      <span className="text-[13px]">Offline — changes will sync automatically</span>
    </div>
  );
}
