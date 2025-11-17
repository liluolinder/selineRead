import { requireCJLib } from 'libark_interop_loader.so'
import { CJLib } from './api/cjAPI'

export const CJLoader = requireCJLib("libohos_app_cangjie_entry.so") as CJLib