@ObservedV2
export class BasicDataSource<T> implements IDataSource {
    private listeners: DataChangeListener[] = [];
    @Trace dataArray: T[] = [];

    public totalCount(): number {
        return this.dataArray.length;
    }

    public getData(index: number): T {
        return this.dataArray[index];
    }

    registerDataChangeListener(listener: DataChangeListener): void {
        if (this.listeners.indexOf(listener) === -1) {
            // r1Chk
            this.listeners.push(listener);
        }
    }

    unregisterDataChangeListener(listener: DataChangeListener): void {
        const pos = this.listeners.indexOf(listener);
        if (pos >= 0) {
            this.listeners.splice(pos, 1);
        }
    }

    public pushUnshiftData(index: T): number {
        const newID = this.dataArray.unshift(index);
        this.notifyDataReload();
        return newID;
    }

    public pushData(index: T): number {
        const newID = this.dataArray.push(index);
        this.notifyDataReload();
        return newID;
    }

    public clearData() {
        this.dataArray = []
        this.notifyDataReload();
    }

    notifyDataReload(): void {
        this.listeners.forEach(listener => {
            listener.onDataReloaded();
        });
    }

    notifyDataAdd(index: number): void {
        this.listeners.forEach(listener => {
            listener.onDataAdd(index);
        });
    }

    notifyDataChange(index: number): void {
        this.listeners.forEach(listener => {
            listener.onDataChange(index);
        });
    }

    notifyDataDelete(index: number): void {
        this.listeners.forEach(listener => {
            listener.onDataDelete(index);
        });
    }

    notifyDataMove(from: number, to: number): void {
        this.listeners.forEach(listener => {
            listener.onDataMove(from, to);
        });
    }

    notifyDatasetChange(operations: DataOperation[]): void {
        this.listeners.forEach(listener => {
            listener.onDatasetChange(operations);
        });
    }
}